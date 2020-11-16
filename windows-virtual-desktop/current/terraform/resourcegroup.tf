## Creating a resource group to host all WVD related resources
resource "azurerm_resource_group" "wvd_resource_group" {
  name     = var.wvd_resource_group["resource_group_name"]
  location = var.wvd_resource_group["location"]
}