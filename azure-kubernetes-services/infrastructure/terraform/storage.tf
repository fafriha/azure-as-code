resource "azurerm_storage_account" "dors_files" {
  name                      = var.dors_storage["account_name"]
  location                  = azurerm_resource_group.dors_resource_group.location
  resource_group_name       = azurerm_resource_group.dors_resource_group.name
  account_kind              = var.dors_storage["account_kind"]
  account_tier              = var.dors_storage["account_tier"]
  account_replication_type  = var.dors_storage["replication_type"]
  enable_https_traffic_only = var.dors_storage["enable_https"]
}

resource "azurerm_storage_share" "dors_files" {

  name                 = var.dors_storage["share_name"]
  storage_account_name = azurerm_storage_account.dors_profiles.name
  quota                = var.dors_storage["share_quota"]
}