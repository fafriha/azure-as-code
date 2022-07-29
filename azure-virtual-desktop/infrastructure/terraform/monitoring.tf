## Creating Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "avd_log_analytics_workspace" {
  name                       = var.avd_monitoring["log_analytics_workspace_name"]
  location                   = azurerm_resource_group.avd_rgs["management"].location
  resource_group_name        = azurerm_resource_group.avd_rgs["management"].name
  sku                        = var.avd_monitoring["log_analytics_workspace_sku"]
  retention_in_days          = var.avd_monitoring["retention_in_days"]
  internet_ingestion_enabled = var.avd_monitoring["internet_ingestion_enabled"]
  internet_query_enabled     = var.avd_monitoring["internet_query_enabled"]
  daily_quota_gb             = var.avd_monitoring["daily_quota_gb"]
}

## Enabling Application Insights (for Function App only)
resource "azurerm_application_insights" "avd_application_insights" {
  name                = var.avd_monitoring["app_insights_name"]
  location            = azurerm_resource_group.avd_rgs["management"].location
  resource_group_name = azurerm_resource_group.avd_rgs["management"].name
  application_type    = var.avd_monitoring["app_insights_type"]
}