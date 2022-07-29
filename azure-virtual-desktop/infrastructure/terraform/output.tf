output "registration_key" {
  value     = values(azurerm_virtual_desktop_host_pool_registration_info.avd_registration_info)
  sensitive = "true"
}