resource "azurerm_availability_set" "avd_as" {
  for_each            = { for as in local.session_hosts : as.hostpool_name => as if as.availability_set != "false" }
  name                = format("%s-%s", "avail", each.value.vm_prefix)
  location            = azurerm_resource_group.avd_rgs["compute"].location
  resource_group_name = azurerm_resource_group.avd_rgs["compute"].name
}

## Creating sessions hosts from the latest W11 marketplace image
resource "azurerm_windows_virtual_machine" "avd_hosts" {
  for_each                 = { for host in local.session_hosts : format("%s-%03d", host.vm_prefix, host.index + 1) => host }
  name                     = each.key
  location                 = azurerm_resource_group.avd_rgs["compute"].location
  resource_group_name      = azurerm_resource_group.avd_rgs["compute"].name
  network_interface_ids    = [lookup(azurerm_network_interface.avd_nics, format("%s-%03d-%s", "nic", each.value.index + 1, each.key)).id]
  size                     = each.value.vm_size
  zone                     = each.value.availability_set != "true" ? each.value.index % 3 + 1 : null
  availability_set_id      = each.value.availability_set != "false" ? azurerm_availability_set.avd_as[each.value.hostpool_name].id : null
  admin_username           = azurerm_key_vault_secret.avd_accounts["local-admin"].name
  admin_password           = azurerm_key_vault_secret.avd_accounts["local-admin"].value
  enable_automatic_updates = { for hp in var.avd_hostpools : hp.patch_mode => hp if hp.name == each.value.hostpool_name }
  patch_mode               = { for hp in var.avd_hostpools : hp.patch_mode => hp if hp.name == each.value.hostpool_name }
  license_type             = lookup(var.avd_hostpools, each.value.hostpool_name).license_type

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.avd_msis[replace(each.value.hostpool_name, "hp", "msi")].id]
  }

  source_image_reference {
    publisher = lookup(var.avd_hostpools, each.value.hostpool_name).image_publisher
    offer     = lookup(var.avd_hostpools, each.value.hostpool_name).image_offer
    sku       = lookup(var.avd_hostpools, each.value.hostpool_name).image_sku
    version   = lookup(var.avd_hostpools, each.value.hostpool_name).image_version
  }

  #source_image_id = data.azurerm_image.avd.id

  os_disk {
    name                 = "osDisk-${lower(each.key)}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = "128"
  }

  tags = {
    hostpool = each.value.hostpool_name
  }
}

## Joinging sessions hosts to a Log Analytics Workspace
resource "azurerm_virtual_machine_extension" "avd_join_log_analytics_workspace" {
  for_each                   = azurerm_windows_virtual_machine.avd_hosts
  name                       = "JoinLogAnalyticsWorkspace"
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_hosts[each.key].id
  publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
  type                       = "MicrosoftMonitoringAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
	{
	  "workspaceId": "${azurerm_log_analytics_workspace.avd_log_analytics_workspace.workspace_id}"
	}
SETTINGS

  protected_settings = <<protectedsettings
  {
    "workspaceKey": "${azurerm_log_analytics_workspace.avd_log_analytics_workspace.primary_shared_key}"
  }
protectedsettings
}

## Joining session hosts to the domain
resource "azurerm_virtual_machine_extension" "avd_join_domain" {
  for_each                   = azurerm_windows_virtual_machine.avd_hosts
  name                       = "JoinDomain"
  virtual_machine_id         = azurerm_windows_virtual_machine.avd_hosts[each.key].id
  publisher                  = "Microsoft.Compute"
  type                       = "JsonADDomainExtension"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_virtual_machine_extension.avd_join_log_analytics_workspace]

  lifecycle {
    ignore_changes = [
      settings,
      protected_settings,
    ]
  }

  settings = <<SETTINGS
    {
      "Name": "${var.hub_identity_resources["directory"].domain_name}",
      "OUPath": "${var.hub_identity_resources["directory"].ou_path}",
      "User": "${azurerm_key_vault_secret.avd_accounts["svc-domain-join"].name}@${var.hub_identity_resources["directory"].domain_name}",
      "Restart": "true",
      "Options": "3"
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
    "Password": "${azurerm_key_vault_secret.avd_accounts["svc-domain-join"].value}"
  }
PROTECTED_SETTINGS
}

# Joining session hosts to the host pool
resource "azurerm_virtual_machine_extension" "avd_install_agents" {
  for_each             = azurerm_windows_virtual_machine.avd_hosts
  name                 = "InitializeSessionHost"
  virtual_machine_id   = azurerm_windows_virtual_machine.avd_hosts[each.key].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on           = [azurerm_virtual_machine_extension.avd_join_domain]

  protected_settings = <<PROTECTED_SETTINGS
    {
      "CommandToExecute": "Powershell.exe -ExecutionPolicy Bypass -File ./Initialize-SessionHost.ps1 -AddSessionHostToHostpool ${azurerm_key_vault_secret.avd_registration_tokens[each.value.tags.hostpool].value} -MoveUserProfiles ${azurerm_storage_share.avd_profiles[each.value.tags.hostpool].url}"
    }
  PROTECTED_SETTINGS

  settings = <<SETTINGS
    {
        "fileUris": ["https://raw.githubusercontent.com/faroukfriha/azure-as-code/master/windows-virtual-desktop/current/powershell/script/Initialize-SessionHost.ps1"]
    }
  SETTINGS
}