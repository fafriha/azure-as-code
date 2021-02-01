resource "azurerm_container_registry" "dors" {
  name                     = "${var.dors_container_registry_name}"
  location                 = "${azurerm_resource_group.dors_resource_group.location}"
  resource_group_name      = "${azurerm_resource_group.dors_resource_group.name}"
  sku                      = "Basic"
  admin_enabled            = false
}