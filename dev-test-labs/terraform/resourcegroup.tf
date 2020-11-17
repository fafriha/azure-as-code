resource "azurerm_resource_group" "lab" {
  name     = var.lab_resource_group_name
  location = var.lab_location
}