## Creating App Service Plan
resource "azurerm_app_service_plan" "wvd_app_service_plan" {
  name                = var.wvd_app_service_plan["name"]
  location            = azurerm_resource_group.wvd_resource_group.location
  resource_group_name = azurerm_resource_group.wvd_resource_group.name
  kind                = var.wvd_app_service_plan["kind"]

  sku {
    tier = var.wvd_app_service_plan["tier"]
    size = var.wvd_app_service_plan["size"]
  }
}

## Creating Function App
resource "azurerm_function_app" "wvd_function" {
  for_each                   = var.wvd_function
  name                       = each.value.name
  location                   = azurerm_resource_group.wvd_resource_group.location
  resource_group_name        = azurerm_resource_group.wvd_resource_group.name
  app_service_plan_id        = azurerm_app_service_plan.wvd_app_service_plan.id
  storage_account_name       = azurerm_storage_account.wvd_function.name
  storage_account_access_key = azurerm_storage_account.wvd_function.primary_access_key
  version                    = each.value.version

  identity {
    type = "UserAssigned"
    identity_ids = azurerm_user_assigned_identity.wvd_msi.identity.0.principal_id
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME              = each.value.runtime
    HTTPS_ONLY                            = each.value.https_only
    WEBSITE_RUN_FROM_PACKAGE              = each.value.package_uri
    AzureWebJobsDisableHomepage           = each.value.disable_homepage
    AzureWebJobsSecretStorageKeyVaultName = azurerm_key_vault.wvd_key_vault.name
    APPINSIGHTS_INSTRUMENTATIONKEY        = azurerm_application_insights.wvd_application_insights.instrumentation_key
  }
}