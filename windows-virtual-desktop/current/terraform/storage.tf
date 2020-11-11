################################################### Production ################################################
## This storage account will host a file share used to store all users profiles
resource "azurerm_storage_account" "wvd_profiles" {
  name                      = var.wvd_storage_accounts["profiles_account_name"]
  location                  = azurerm_resource_group.wvd.location
  resource_group_name       = azurerm_resource_group.wvd.name
  account_kind              = var.wvd_storage_accounts["profiles_account_kind"]
  account_tier              = var.wvd_storage_accounts["profiles_account_tier"]
  account_replication_type  = var.wvd_storage_accounts["replication_type"]
  enable_https_traffic_only = var.wvd_storage_accounts["enable_https"]
}

# This storage account will host a file share used to store functions content
resource "azurerm_storage_account" "wvd_functions" {
  name                      = var.wvd_storage_accounts["function_account_name"]
  location                  = azurerm_resource_group.wvd.location
  resource_group_name       = azurerm_resource_group.wvd.name
  account_kind              = var.wvd_storage_accounts["function_account_kind"]
  account_tier              = var.wvd_storage_accounts["function_account_tier"]
  account_replication_type  = var.wvd_storage_accounts["replication_type"]
  enable_https_traffic_only = var.wvd_storage_accounts["enable_https"]
}

## These file share will be used to store all users profiles 
resource "azurerm_storage_share" "wvd_share" {
  for_each             = { for hp in var.wvd_host_pools : format("%s-profiles", hp.name) => hp }
  name                 = each.key
  storage_account_name = azurerm_storage_account.wvd_profiles.name
  quota                = 5120
}

################################################### Canary ################################################