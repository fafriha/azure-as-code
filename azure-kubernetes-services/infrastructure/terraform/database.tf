resource "azurerm_mysql_server" "dors_mysql_server" {
  name                = var.dors_database["mysql_server_name"]
  location            = azurerm_resource_group.dors_resource_group.location
  resource_group_name = azurerm_resource_group.dors_resource_group.name

  administrator_login          = var.dors_admin_account["username"]
  administrator_login_password = var.dors_admin_account["password"]

  sku_name   = var.dors_database["sku_name"]
  storage_mb = var.dors_database["storage_mb"]
  version    = var.dors_database["version"]

  auto_grow_enabled                 = var.dors_database["auto_grow_enabled"]
  backup_retention_days             = var.dors_database["backup_retention_days"]
  geo_redundant_backup_enabled      = var.dors_database["geo_redundant_backup_enabled"]
  infrastructure_encryption_enabled = var.dors_database["infrastructure_encryption_enabled"]
  public_network_access_enabled     = var.dors_database["public_network_access_enabled"]
  ssl_enforcement_enabled           = var.dors_database["ssl_enforcement_enabled"]
  ssl_minimal_tls_version_enforced  = var.dors_database["ssl_minimal_tls_version_enforced"]
}

resource "azurerm_mysql_database" "dors_database" {
  name                = var.dors_database["mysql_database_name"]
  resource_group_name = azurerm_resource_group.dors_resource_group.name
  server_name         = azurerm_mysql_server.dors_mysql_server.name
  charset             = var.dors_database["charset"]
  collation           = var.dors_database["collation"]
}