resource "azurerm_mysql_server" "dors" {
  name                = var.dors_mysql_server_name
  location            = azurerm_resource_group.dors_resource_group.location
  resource_group_name = azurerm_resource_group.dors_resource_group.name

  administrator_login          = ""
  administrator_login_password = ""

  sku_name   = "B_Gen5_2"
  storage_mb = 5120
  version    = "5.7"

  auto_grow_enabled                 = true
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = true
  infrastructure_encryption_enabled = true
  public_network_access_enabled     = false
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
}

resource "azurerm_mysql_database" "dors" {
  name                = var.dors_mysql_database_name
  resource_group_name = azurerm_resource_group.dors_resource_group.name
  server_name         = azurerm_mysql_server.dors.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}