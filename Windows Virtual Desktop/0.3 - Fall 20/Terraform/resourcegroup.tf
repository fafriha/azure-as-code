## This resource group will contain all the components below 
resource "azurerm_resource_group" "wvd" {
  name     = var.wvd_resource_group["name"]
  location = var.wvd_resource_group["location"]
}