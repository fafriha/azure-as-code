resource "azurerm_container_registry" "core" {
  name                     = "${var.log_analytics_workspace_name}acr"
  location                 = "${data.azurerm_resource_group.core.location}"
  resource_group_name      = "${data.azurerm_resource_group.core.name}"
  sku                      = "Basic"
  admin_enabled            = false
}