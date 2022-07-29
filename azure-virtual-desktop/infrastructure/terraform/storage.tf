### Azure File Share ####
# Creating a storage account to store all user profiles and relevant packages
resource "azurerm_storage_account" "avd_profiles" {
  name                      = var.avd_storage["profiles_account_name"]
  location                  = azurerm_resource_group.avd_rgs["storage"].location
  resource_group_name       = azurerm_resource_group.avd_rgs["storage"].name
  account_kind              = var.avd_storage["profiles_account_kind"]
  account_tier              = var.avd_storage["profiles_account_tier"]
  account_replication_type  = var.avd_storage["replication_type"]
  enable_https_traffic_only = var.avd_storage["enable_https"]

  azure_files_authentication {
    directory_type = var.hub_identity_resources["directory"].type
    active_directory {
      storage_sid         = var.hub_identity_resources["directory"].storage_sid
      domain_name         = var.hub_identity_resources["directory"].domain_name
      domain_sid          = var.hub_identity_resources["directory"].domain_sid
      domain_guid         = var.hub_identity_resources["directory"].domain_guid
      forest_name         = var.hub_identity_resources["directory"].forest_name
      netbios_domain_name = var.hub_identity_resources["directory"].netbios_domain_name
    }
  }
}

# Creating an Azure Files share to store all user profiles
resource "azurerm_storage_share" "avd_profiles" {
  for_each             = { for hp in var.avd_hostpools : hp.name => hp }
  name                 = each.key
  storage_account_name = azurerm_storage_account.avd_profiles.name
  quota                = var.avd_storage["volume_or_share_quota"]
}

## Creating a storage account to store Function App data
resource "azurerm_storage_account" "avd_function" {
  name                      = var.avd_storage["function_account_name"]
  location                  = azurerm_resource_group.avd_rgs["storage"].location
  resource_group_name       = azurerm_resource_group.avd_rgs["storage"].name
  account_kind              = var.avd_storage["function_account_kind"]
  account_tier              = var.avd_storage["function_account_tier"]
  account_replication_type  = var.avd_storage["replication_type"]
  enable_https_traffic_only = var.avd_storage["enable_https"]
}


#### Azure NetApp Files ####
## Creating a NetApp account to store all user profiles
resource "azurerm_netapp_account" "avd_profiles" {
  name                = var.avd_storage["profiles_account_name"]
  location            = azurerm_resource_group.avd_rgs["storage"].location
  resource_group_name = azurerm_resource_group.avd_rgs["storage"].name

  active_directory {
    username            = azurerm_key_vault_secret.avd_accounts["svc-domain-join"].name
    password            = azurerm_key_vault_secret.avd_accounts["svc-domain-join"].value
    smb_server_name     = var.avd_storage["profiles_account_name"]
    dns_servers         = var.hub_network_resources["dns_servers_ip"]
    domain              = var.hub_identity_resources["directory"].domain_name
    organizational_unit = var.hub_identity_resources["directory"].ou_path
  }
}

# Creating a NetApp pool to store all user profiles
resource "azurerm_netapp_pool" "avd_profiles" {
  name                = var.avd_storage["profiles_pool_name"]
  location            = azurerm_resource_group.avd_rgs["storage"].location
  resource_group_name = azurerm_resource_group.avd_rgs["storage"].name
  account_name        = azurerm_netapp_account.avd_profiles.name
  service_level       = var.avd_storage["profiles_account_tier"]
  size_in_tb          = var.avd_storage["pool_size"]
}

# Creating a NetApp volume to store all user profiles
resource "azurerm_netapp_volume" "avd_profiles" {
  for_each            = { for hp in var.avd_hostpools : hp.name => hp }
  name                = each.key
  location            = azurerm_resource_group.avd_rgs["storage"].location
  resource_group_name = azurerm_resource_group.avd_rgs["storage"].name
  account_name        = azurerm_netapp_account.avd_profiles.name
  pool_name           = azurerm_netapp_pool.avd_profiles.name
  volume_path         = var.avd_storage["volume_path"]
  service_level       = var.avd_storage["profiles_account_tier"]
  subnet_id           = azurerm_virtual_network.avd_virtual_networks[each.key].subnet.*.id[0]
  protocols           = var.avd_storage["volume_protocol"]
  storage_quota_in_gb = var.avd_storage["volume_or_share_quota"]

  lifecycle {
    prevent_destroy = true
  }
}