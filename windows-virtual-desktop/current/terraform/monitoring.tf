## Creating Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "wvd_log_analytics_workspace" {
  name                = var.wvd_monitoring["log_analytics_workspace_name"]
  location            = azurerm_resource_group.wvd_resource_group.location
  resource_group_name = azurerm_resource_group.wvd_resource_group.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

## Enabling Application Insights (for Function App only)
resource "azurerm_application_insights" "wvd_application_insights" {
  name                = var.wvd_monitoring["app_insights_name"]
  location            = azurerm_resource_group.wvd_resource_group.location
  resource_group_name = azurerm_resource_group.wvd_resource_group.name
  application_type    = var.wvd_monitoring["app_insights_type"]
}

## Deplying workbooks to monitor WVD usage ... Stay tuned