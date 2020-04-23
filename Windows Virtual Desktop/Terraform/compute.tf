################################################### Windows Virtual Desktop ################################################

## These virtual machines will be used as Windows Virtual Desktop session hosts
resource "azurerm_windows_virtual_machine" "wvd_hosts" {
  count                     = var.wvd_rdsh_count
  name                      = "${var.wvd_vm_prefix}0${count.index+1}"
  location                  = azurerm_resource_group.wvd.location
  resource_group_name       = azurerm_resource_group.wvd.name
  network_interface_ids     = [azurerm_network_interface.wvd_hosts[count.index].id]
  size                      = var.wvd_vm_size
  #zone                     = "${count.index+1}"
  zone                      = 3
  admin_username            = azurerm_key_vault_secret.wvd_local_admin_account.name
  admin_password            = azurerm_key_vault_secret.wvd_local_admin_account.value
  enable_automatic_updates  = false

  source_image_reference {
    #id       = data.azurerm_image.wvd.id
    publisher = "MicrosoftWindowsDesktop"
    offer     = "office-365"
    sku       = "19h2-evd-o365pp"
    version   = "latest"
  }

  os_disk {
    name                  = "osDisk-${lower(var.wvd_vm_prefix)}${count.index+1}-01"
    caching               = "ReadWrite"
    storage_account_type  = "Premium_LRS"
    disk_size_gb          = "128"
  }
}

# ## This extension will join all session hosts to the log analytics workspace
# resource "azurerm_virtual_machine_extension" "wvd_join_log_analytics_workspace" {
#   count                      = var.wvd_rdsh_count
#   name                       = "ext-log-join"
#   virtual_machine_id         = azurerm_windows_virtual_machine.wvd_hosts.*.id[count.index]
#   publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
#   type                       = "MicrosoftMonitoringAgent"
#   type_handler_version       = "1.0"
#   auto_upgrade_minor_version = true

#   settings = <<SETTINGS
# 	{
# 	  "workspaceId": "${azurerm_log_analytics_workspace.wvd_monitoring.workspace_id}"
# 	}
# SETTINGS

#   protected_settings = <<protectedsettings
#   {
#     "workspaceKey": "${azurerm_log_analytics_workspace.wvd_monitoring.primary_shared_key}"
#   }
# protectedsettings
# }

## This extension will join all session hosts to the domain
resource "azurerm_virtual_machine_extension" "wvd_join_domain" {
  count                      = var.wvd_rdsh_count
  name                       = "ext-domain-join"
  virtual_machine_id         = azurerm_windows_virtual_machine.wvd_hosts.*.id[count.index]
  publisher                  = "Microsoft.Compute"
  type                       = "JsonADDomainExtension"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true

  lifecycle {
    ignore_changes = [
      settings,
      protected_settings,
    ]
  }

  settings = <<SETTINGS
    {
      "Name": "${var.wvd_domain_name}",
      "OUPath": "${var.wvd_ou_path}",
      "User": "${azurerm_key_vault_secret.wvd_domain_join_account.name}@${var.wvd_domain_name}",
      "Restart": "true",
      "Options": "3"
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
    "Password": "${azurerm_key_vault_secret.wvd_domain_join_account.value}"
  }
PROTECTED_SETTINGS
}

## This extension will join all session hosts to the Windows Virtual Desktop host pool
resource "azurerm_virtual_machine_extension" "wvd_join_hostpool" {
  count                      = var.wvd_rdsh_count
  name                       = "ext-hostpool-join"
  virtual_machine_id         = azurerm_windows_virtual_machine.wvd_hosts.*.id[count.index]
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
{
    "modulesURL": "https://raw.githubusercontent.com/faroukfriha/azure-as-code/master/Windows%20Virtual%20Desktop/PowerShell/Configuration.zip",
    "configurationFunction": "Configuration.ps1\\RegisterSessionHost",
     "properties": {
        "TenantAdminCredentials":{
            "userName":"${azurerm_key_vault_secret.wvd_tenant_app.name}",
            "password":"PrivateSettingsRef:tenantAdminPassword"
        },
        "RDBrokerURL": "https://rdbroker.wvd.microsoft.com",
        "DefinedTenantGroupName":"${var.wvd_tenant_group_name}",
        "TenantName":"${var.wvd_tenant_name}",
        "HostPoolName":"${var.wvd_host_pool_name}",
        "Hours":"${var.wvd_registration_expiration_hours}",
        "isServicePrincipal":"true",
        "AadTenantId":"${var.global_aad_tenant_id}",
        "UserProfileTargetPath":"${azurerm_storage_share.wvd.url}",
        "WorkspaceID":"${azurerm_log_analytics_workspace.wvd.workspace_id}",
        "WorkspacePrimaryKey":"${azurerm_log_analytics_workspace.wvd.primary_shared_key}"
  }
}

SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
    "items":{
    "tenantAdminPassword": "${azurerm_key_vault_secret.wvd_tenant_app.value}"
  }
}
PROTECTED_SETTINGS
}