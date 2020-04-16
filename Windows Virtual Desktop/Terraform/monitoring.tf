################################################### Windows Virtual Desktop ################################################

## This log analytics workspace will be used to momintor all session hosts
resource "azurerm_log_analytics_workspace" "wvd_monitoring" {
  name                      = var.wvd_log_analytics_workspace_name
  location                  = azurerm_resource_group.wvd.location
  resource_group_name       = azurerm_resource_group.wvd.name
  sku                       = "PerGB2018"
  retention_in_days         = 30
}