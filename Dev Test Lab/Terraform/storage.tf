resource "azurerm_storage_account" "lab" {
  name                      = var.lab_storage_account_name
  location                  = azurerm_resource_group.lab.location
  resource_group_name       = azurerm_resource_group.lab.name
  account_tier              = "Standard"
  account_replication_type  = "LRS"
}