resource "azurerm_container_registry" "dors_acr" {
  name                     = var.dors_acr["registry_name"]
  location                 = azurerm_resource_group.dors_resource_group.location
  resource_group_name      = azurerm_resource_group.dors_resource_group.name
  sku                      = var.dors_acr["sku"]
  admin_enabled            = var.dors_acr["admin_enabled"]
}