resource "azurerm_dev_test_lab" "lab" {
  name                = var.lab_name
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
}