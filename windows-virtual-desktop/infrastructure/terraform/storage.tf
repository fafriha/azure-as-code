## Creating a storage account to store all user profiles and relevant packages
resource "azurerm_storage_account" "wvd_profiles" {
  name                      = var.wvd_storage["profiles_account_name"]
  location                  = azurerm_resource_group.wvd_resource_group.location
  resource_group_name       = azurerm_resource_group.wvd_resource_group.name
  account_kind              = var.wvd_storage["profiles_account_kind"]
  account_tier              = var.wvd_storage["profiles_account_tier"]
  account_replication_type  = var.wvd_storage["replication_type"]
  enable_https_traffic_only = var.wvd_storage["enable_https"]
}

## Creating a storage account to store Function App data
resource "azurerm_storage_account" "wvd_function" {
  name                      = var.wvd_storage["function_account_name"]
  location                  = azurerm_resource_group.wvd_resource_group.location
  resource_group_name       = azurerm_resource_group.wvd_resource_group.name
  account_kind              = var.wvd_storage["function_account_kind"]
  account_tier              = var.wvd_storage["function_account_tier"]
  account_replication_type  = var.wvd_storage["replication_type"]
  enable_https_traffic_only = var.wvd_storage["enable_https"]
}

## Creating a file share to store all user profiles
resource "azurerm_storage_share" "wvd_profiles" {
  for_each             = { for hp in var.wvd_hostpool : format("%s", hp.name) => hp }
  name                 = each.key
  storage_account_name = azurerm_storage_account.wvd_profiles.name
  quota                = 5120
}