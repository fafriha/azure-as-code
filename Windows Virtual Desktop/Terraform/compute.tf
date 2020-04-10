################################################### Hub ################################################

## These virtual machines will be used as domain controllers
# resource "azurerm_windows_virtual_machine" "wvd" {
#   count                     = var.wvd_rdsh_count
#   name                      = "${var.wvd_vm_prefix}0${count.index+1}"
#   location                  = azurerm_resource_group.wvd.location
#   resource_group_name       = azurerm_resource_group.wvd.name
#   network_interface_ids     = [azurerm_network_interface.wvd[count.index].id]
#   size                      = var.wvd_vm_size
#   zone                     = "${count.index+1}"
#   zone                      = 3
#   admin_username            = var.wvd_local_admin_name
#   admin_password            = azurerm_key_vault_secret.wvd_local_admin.value
#   enable_automatic_updates  = false

#   source_image_reference {
#     id       = data.azurerm_image.wvd.id
#     publisher = "MicrosoftWindowsDesktop"
#     offer     = "office-365"
#     sku       = "19h2-evd-o365pp"
#     version   = "latest"
#   }

#   os_disk {
#     name                  = "osDisk-${lower(var.wvd_vm_prefix)}${count.index+1}-0${count.index+1}"
#     caching               = "ReadWrite"
#     storage_account_type  = "Premium_LRS"
#     disk_size_gb          = var.wvd_os_disk_size
#   }
# }

# # This extension will create a new domain
# resource "azurerm_virtual_machine_extension" "wvd_log_analytics" {
#   count                      = var.wvd_extension_log_analytics ? var.wvd_rdsh_count : 0
#   name                       = "ext-log-join"
#   virtual_machine_id         = azurerm_windows_virtual_machine.wvd.*.id[count.index]
#   publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
#   type                       = "MicrosoftMonitoringAgent"
#   type_handler_version       = "1.0"
#   auto_upgrade_minor_version = true

#   settings = <<SETTINGS
# 	{
# 	  "workspaceId": "${azurerm_log_analytics_workspace.wvd.workspace_id}"
# 	}
# SETTINGS

#   protected_settings = <<protectedsettings
#   {
#     "workspaceKey": "${azurerm_log_analytics_workspace.wvd.primary_shared_key}"
#   }
# protectedsettings
# }

################################################### Windows Virtual Desktop ################################################

## These virtual machines will be used as Windows Virtual Desktop session hosts
resource "azurerm_windows_virtual_machine" "wvd" {
  count                     = var.wvd_rdsh_count
  name                      = "${var.wvd_vm_prefix}0${count.index+1}"
  location                  = azurerm_resource_group.wvd.location
  resource_group_name       = azurerm_resource_group.wvd.name
  network_interface_ids     = [azurerm_network_interface.wvd[count.index].id]
  size                      = var.wvd_vm_size
  #zone                     = "${count.index+1}"
  zone                      = 3
  admin_username            = var.wvd_local_admin_name
  admin_password            = azurerm_key_vault_secret.wvd_local_admin.value
  enable_automatic_updates  = false

  source_image_reference {
    #id       = data.azurerm_image.wvd.id
    publisher = "MicrosoftWindowsDesktop"
    offer     = "office-365"
    sku       = "19h2-evd-o365pp"
    version   = "latest"
  }

  os_disk {
    name                  = "osDisk-${lower(var.wvd_vm_prefix)}${count.index+1}-0${count.index+1}"
    caching               = "ReadWrite"
    storage_account_type  = "Premium_LRS"
    disk_size_gb          = var.wvd_os_disk_size
  }
}

## This extension will join all session hosts to the log analytics workspace
resource "azurerm_virtual_machine_extension" "wvd_log_analytics" {
  count                      = var.wvd_extension_log_analytics ? var.wvd_rdsh_count : 0
  name                       = "ext-log-join"
  virtual_machine_id         = azurerm_windows_virtual_machine.wvd.*.id[count.index]
  publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
  type                       = "MicrosoftMonitoringAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
	{
	  "workspaceId": "${azurerm_log_analytics_workspace.wvd.workspace_id}"
	}
SETTINGS

  protected_settings = <<protectedsettings
  {
    "workspaceKey": "${azurerm_log_analytics_workspace.wvd.primary_shared_key}"
  }
protectedsettings
}

## This extension will join all session hosts to the domain
resource "azurerm_virtual_machine_extension" "wvd_domain_join" {
  count                      = var.wvd_domain_joined ? var.wvd_rdsh_count : 0
  name                       = "ext-domain-join"
  virtual_machine_id         = azurerm_windows_virtual_machine.wvd.*.id[count.index]
  publisher                  = "Microsoft.Compute"
  type                       = "JsonADDomainExtension"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_virtual_machine_extension.wvd_log_analytics]

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
      "User": "${var.wvd_domain_join_name}@${var.wvd_domain_name}",
      "Restart": "true",
      "Options": "3"
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
    "Password": "${azurerm_key_vault_secret.wvd_domain_join.value}"
  }
PROTECTED_SETTINGS
}

## This extension will join all session hosts to the Windows Virtual Desktop host pool
resource "azurerm_virtual_machine_extension" "wvd_hostpool_join" {
  count                      = var.wvd_rdsh_count
  name                       = "ext-hostpool-join"
  virtual_machine_id         = azurerm_windows_virtual_machine.wvd.*.id[count.index]
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true
  depends_on                 = [azurerm_virtual_machine_extension.wvd_domain_join]

  settings = <<SETTINGS
{
    "modulesURL": "${var.wvd_base_url}/PowerShell/Configuration.zip",
    "configurationFunction": "Configuration.ps1\\RegisterSessionHost",
     "properties": {
        "TenantAdminCredentials":{
            "userName":"${var.wvd_tenant_app_client_id}",
            "password":"PrivateSettingsRef:tenantAdminPassword"
        },
        "RDBrokerURL": "${var.wvd_rdbroker_url}",
        "DefinedTenantGroupName":"${var.wvd_tenant_group_name}",
        "TenantName":"${var.wvd_tenant_name}",
        "HostPoolName":"${var.wvd_host_pool_name}",
        "Hours":"${var.wvd_registration_expiration_hours}",
        "isServicePrincipal":"${var.wvd_is_service_principal}",
        "AadTenantId":"${var.aad_tenant_id}"
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

## This extension will deploy the FSlogix agent to all session hosts
# resource "azurerm_virtual_machine_extension" "wvd_fslogix" {
#   count                      = var.wvd_rdsh_count
#   name                       = "ext-sepago-add"
#   virtual_machine_id         = azurerm_windows_virtual_machine.wvd.*.id[count.index]
#   publisher                  = "Microsoft.Powershell"
#   type                       = "DSC"
#   type_handler_version       = "2.73"
#   auto_upgrade_minor_version = true

#   settings = <<SETTINGS
# {
#     "modulesURL": "${var.wvd_base_url}/PowerShell/Configuration.zip",
#     "configurationFunction": "Configuration.ps1\\AdditionalSessionHosts",
#      "properties": {
#         "TenantAdminCredentials":{
#             "userName":"${var.wvd_tenant_app_id}",
#             "password":"PrivateSettingsRef:tenantAdminPassword"
#         },
#         "RDBrokerURL": "${var.wvd_rdbroker_url}",
#         "DefinedTenantGroupName":"${var.wvd_tenant_group_name}",
#         "TenantName":"${var.wvd_tenant_name}",
#         "HostPoolName":"${var.wvd_host_pool_name}",
#         "Hours":"${var.wvd_registration_expiration_hours}",
#         "isServicePrincipal":"${var.wvd_is_service_principal}",
#         "AadTenantId":"${var.aad_tenant_id}"
#   }
# }

# SETTINGS

#   protected_settings = <<PROTECTED_SETTINGS
#   {
#     "items":{
#     "tenantAdminPassword": "${data.azurerm_key_vault_secret.wvd_tenant_app.value}"
#   }
# }
# PROTECTED_SETTINGS
# }

## This extension will deploy the Sepago agent to enchance the monitorng experiencee
# resource "azurerm_virtual_machine_extension" "wvd_sepago" {
#   count                      = var.wvd_rdsh_count
#   name                       = "ext-sepago-add"
#   virtual_machine_id         = azurerm_windows_virtual_machine.wvd.*.id[count.index]
#   publisher                  = "Microsoft.Powershell"
#   type                       = "DSC"
#   type_handler_version       = "2.73"
#   auto_upgrade_minor_version = true

#   settings = <<SETTINGS
# {
#     "modulesURL": "${var.wvd_base_url}/PowerShell/Configuration.zip",
#     "configurationFunction": "Configuration.ps1\\AdditionalSessionHosts",
#      "properties": {
#         "TenantAdminCredentials":{
#             "userName":"${var.wvd_tenant_app_id}",
#             "password":"PrivateSettingsRef:tenantAdminPassword"
#         },
#         "RDBrokerURL": "${var.wvd_rdbroker_url}",
#         "DefinedTenantGroupName":"${var.wvd_tenant_group_name}",
#         "TenantName":"${var.wvd_tenant_name}",
#         "HostPoolName":"${var.wvd_host_pool_name}",
#         "Hours":"${var.wvd_registration_expiration_hours}",
#         "isServicePrincipal":"${var.wvd_is_service_principal}",
#         "AadTenantId":"${var.aad_tenant_id}"
#   }
# }

# SETTINGS

#   protected_settings = <<PROTECTED_SETTINGS
#   {
#     "items":{
#     "tenantAdminPassword": "${data.azurerm_key_vault_secret.wvd_tenant_app.value}"
#   }
# }
# PROTECTED_SETTINGS
# }

## This extension will join the sotrage account to the domain
# resource "azurerm_virtual_machine_extension" "wvd_adds_enable" {
#   count                      = var.wvd_rdsh_count
#   name                       = "ext-sepago-add"
#   virtual_machine_id         = azurerm_windows_virtual_machine.wvd.*.id[count.index]
#   publisher                  = "Microsoft.Powershell"
#   type                       = "DSC"
#   type_handler_version       = "2.73"
#   auto_upgrade_minor_version = true

#   settings = <<SETTINGS
# {
#     "modulesURL": "${var.wvd_base_url}/PowerShell/Configuration.zip",
#     "configurationFunction": "Configuration.ps1\\AdditionalSessionHosts",
#      "properties": {
#         "TenantAdminCredentials":{
#             "userName":"${var.wvd_tenant_app_id}",
#             "password":"PrivateSettingsRef:tenantAdminPassword"
#         },
#         "RDBrokerURL": "${var.wvd_rdbroker_url}",
#         "DefinedTenantGroupName":"${var.wvd_tenant_group_name}",
#         "TenantName":"${var.wvd_tenant_name}",
#         "HostPoolName":"${var.wvd_host_pool_name}",
#         "Hours":"${var.wvd_registration_expiration_hours}",
#         "isServicePrincipal":"${var.wvd_is_service_principal}",
#         "AadTenantId":"${var.aad_tenant_id}"
#   }
# }

# SETTINGS

#   protected_settings = <<PROTECTED_SETTINGS
#   {
#     "items":{
#     "tenantAdminPassword": "${data.azurerm_key_vault_secret.wvd_tenant_app.value}"
#   }
# }
# PROTECTED_SETTINGS
# }