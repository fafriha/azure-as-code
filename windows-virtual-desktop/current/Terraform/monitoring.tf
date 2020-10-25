################################################### Production & Canary ################################################
## This log analytics workspace will be used to momintor all session hosts
resource "azurerm_log_analytics_workspace" "wvd" {
  name                      = var.wvd_log_analytics_workspace_name
  location                  = azurerm_resource_group.wvd.location
  resource_group_name       = azurerm_resource_group.wvd.name
  sku                       = "PerGB2018"
  retention_in_days         = 30
}

# resource "azurerm_application_insights" "wvd" {
#   name                = var.wvd_app_insights["name"]
#   location            = azurerm_resource_group.wvd.location
#   resource_group_name = azurerm_resource_group.wvd.name
#   application_type    = var.wvd_app_insights["type"]
# }

## Reserved for workbook creation using ARM template