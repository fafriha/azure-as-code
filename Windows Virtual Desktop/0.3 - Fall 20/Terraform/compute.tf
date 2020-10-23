# ## These virtual machines will be used as Windows Virtual Desktop session hosts
# resource "azurerm_windows_virtual_machine" "wvd_hosts" {
#   for_each                  = {for s in local.session_hosts : format("%s-%02d", s.vm_prefix, s.index+1) => s}
#   name                      = each.key
#   location                  = azurerm_resource_group.wvd.location
#   resource_group_name       = azurerm_resource_group.wvd.name
#   network_interface_ids     = [azurerm_network_interface.wvd_hosts["${each.key}-01"].id]
#   size                      = each.value.vm_size
#   zone                      = each.value.index+1
#   admin_username            = azurerm_key_vault_secret.wvd_local_admin_account.name
#   admin_password            = azurerm_key_vault_secret.wvd_local_admin_account.value
#   enable_automatic_updates  = false

#   source_image_reference {
#     publisher = "MicrosoftWindowsDesktop"
#     offer     = "office-365"
#     sku       = "19h2-evd-o365pp"
#     version   = "latest"
#   }

#   #source_image_id = data.azurerm_image.wvd.id

#   os_disk {
#     name                  = "osDisk-${lower(each.key)}-01"
#     caching               = "ReadWrite"
#     storage_account_type  = "Premium_LRS"
#     disk_size_gb          = "128"
#   }

#   tags = {
#     Hostpool = each.value.host_pool_name
#   }
# }

# # ## This extension will join all session hosts to the log analytics workspace
# # resource "azurerm_virtual_machine_extension" "wvd_join_log_analytics_workspace" {
# #   count                      = var.wvd_vm["count"]
# #   name                       = "ext-log-join"
# #   virtual_machine_id         = azurerm_windows_virtual_machine.wvd_hosts.*.id[count.index]
# #   publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
# #   type                       = "MicrosoftMonitoringAgent"
# #   type_handler_version       = "1.0"
# #   auto_upgrade_minor_version = true

# #   settings = <<SETTINGS
# # 	{
# # 	  "workspaceId": "${azurerm_log_analytics_workspace.wvd.workspace_id}"
# # 	}
# # SETTINGS

# #   protected_settings = <<protectedsettings
# #   {
# #     "workspaceKey": "${azurerm_log_analytics_workspace.wvd.primary_shared_key}"
# #   }
# # protectedsettings
# # }