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

## Creating an Azure Files share to store all user profiles
resource "azurerm_storage_share" "wvd_profiles" {
  for_each             = { for hp in var.wvd_hostpool : format("%s", hp.name) => hp }
  name                 = each.key
  storage_account_name = azurerm_storage_account.wvd_profiles.name
  quota                = var.wvd_storage["volume_or_share_quota"]
}

## Creating a NetApp account to store all user profiles
resource "azurerm_netapp_account" "wvd_profiles" {
  name                      = var.wvd_storage["profiles_account_name"]
  location                  = azurerm_resource_group.wvd_resource_group.location
  resource_group_name       = azurerm_resource_group.wvd_resource_group.name

  active_directory {
    username            = var.wvd_domain_join_account["username"]
    password            = var.wvd_domain_join_account["password"]
    smb_server_name     = var.wvd_storage["profiles_account_name"]
    dns_servers         = data.azurerm_virtual_network.hub_virtual_network.dns_servers
    domain              = var.wvd_domain["domain_name"]
    organizational_unit = var.wvd_domain["ou_path"]
  }
}

## Creating a NetApp pool to store all user profiles
resource "azurerm_netapp_pool" "wvd_profiles" {
  name                      = var.wvd_storage["profiles_pool_name"]
  location                  = azurerm_resource_group.wvd_resource_group.location
  resource_group_name       = azurerm_resource_group.wvd_resource_group.name
  account_name              = azurerm_netapp_account.wvd_profiles.name
  service_level             = var.wvd_storage["profiles_account_tier"]
  size_in_tb                = var.wvd_storage["pool_size"]
}

## Creating a NetApp volume to store all user profiles
resource "azurerm_netapp_volume" "wvd_profiles" {
  for_each                  = { for hp in var.wvd_hostpool : format("%s", hp.name) => hp }
  name                      = each.key
  location                  = azurerm_resource_group.wvd_resource_group.location
  resource_group_name       = azurerm_resource_group.wvd_resource_group.name
  account_name              = azurerm_netapp_account.wvd_profiles.name
  pool_name                 = azurerm_netapp_pool.wvd_profiles.name
  volume_path               = var.wvd_storage["volume_path"]
  service_level             = var.wvd_storage["profiles_account_tier"]
  subnet_id                 = azurerm_subnet.wvd_subnets[replace(each.key, "hp", "snet")].id
  protocols                 = var.wvd_storage["volume_protocol"]
  storage_quota_in_gb       = var.wvd_storage["volume_or_share_quota"]

  lifecycle {
    prevent_destroy = true
  }
}