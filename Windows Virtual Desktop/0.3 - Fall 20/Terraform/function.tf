## Azure function
resource "azurerm_app_service_plan" "wvd_asp" {
  name                = var.wvd_app_service_plan
  location            = azurerm_resource_group.wvd.location
  resource_group_name = azurerm_resource_group.wvd.name
  kind                = "FunctionApp"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "wvd" {
  for_each                   = var.wvd_functions
  name                       = each.value.name
  location                   = azurerm_resource_group.wvd.location
  resource_group_name        = azurerm_resource_group.wvd.name
  app_service_plan_id        = azurerm_app_service_plan.wvd_asp.id
  storage_account_name       = azurerm_storage_account.wvd.name
  storage_account_access_key = azurerm_storage_account.wvd.primary_access_key
  version                    = "~3"

  identity {
      type = "SystemAssigned"
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME      = "powershell"
    FUNCTION_APP_EDIT_MODE        = "readonly"
    HTTPS_ONLY                    = "true"
    WEBSITE_RUN_FROM_PACKAGE      = each.value.package_uri
    AzureWebJobsDisableHomepage   = "true"
  }
}