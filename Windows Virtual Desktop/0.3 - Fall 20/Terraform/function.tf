## Azure function
resource "azurerm_app_service_plan" "wvd" {
  name                = var.wvd_app_service_plan["name"]
  location            = azurerm_resource_group.wvd.location
  resource_group_name = azurerm_resource_group.wvd.name
  kind                = var.wvd_app_service_plan["kind"]

  sku {
    tier = var.wvd_app_service_plan["tier"]
    size = var.wvd_app_service_plan["size"]
  }
}

resource "azurerm_function_app" "wvd" {
  for_each                   = var.wvd_functions
  name                       = each.value.name
  location                   = azurerm_resource_group.wvd.location
  resource_group_name        = azurerm_resource_group.wvd.name
  app_service_plan_id        = azurerm_app_service_plan.wvd.id
  storage_account_name       = azurerm_storage_account.wvd.name
  storage_account_access_key = azurerm_storage_account.wvd.primary_access_key
  version                    = each.value.version

  identity {
      type = "SystemAssigned"
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME              = each.value.runtime
    HTTPS_ONLY                            = each.value.https_only
    WEBSITE_RUN_FROM_PACKAGE              = each.value.package_uri
    AzureWebJobsDisableHomepage           = each.value.disable_homepage
    AzureWebJobsSecretStorageType         = each.value.secrets_storage
    AzureWebJobsSecretStorageKeyVaultName = azurerm_key_vault.wvd.name
    APPINSIGHTS_INSTRUMENTATIONKEY        = azurerm_application_insights.wvd.instrumentation_key
  }
}