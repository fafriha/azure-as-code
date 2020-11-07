################################################### Windows Virtual Desktop ################################################

## This resource group will contain all the components below 
resource "azurerm_resource_group" "wvd" {
  name     = var.wvd_resource_group_name
  location = var.wvd_location
}