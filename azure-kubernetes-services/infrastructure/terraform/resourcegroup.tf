## Creating a resource group to host all Dors related resources
resource "azurerm_resource_group" "dors_resource_group" {
  name     = var.dors_resource_group["resource_group_name"]
  location = var.dors_resource_group["location"]
}