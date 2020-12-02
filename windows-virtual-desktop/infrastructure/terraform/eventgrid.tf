## Creating topic to publish all Azure Key Vault events
resource "azurerm_eventgrid_system_topic" "wvd_topic" {
  name                   = var.wvd_events["topic_name"]
  location               = azurerm_resource_group.wvd_resource_group.location
  resource_group_name    = azurerm_resource_group.wvd_resource_group.name
  source_arm_resource_id = azurerm_key_vault.wvd_key_vault.id
  topic_type             = var.wvd_events["topic_type"]
}

## Subscribing to all Azure Key Vault secret expiration events
resource "azurerm_eventgrid_event_subscription" "wvd_subscription" {
  name                 = var.wvd_events["subscription_name"]
  scope                = azurerm_key_vault.wvd_key_vault.id
  included_event_types = ["Microsoft.KeyVault.SecretsExpired"]
  depends_on           = [azurerm_function_app.wvd_function]

  azure_function_endpoint {
    function_id                       = "${azurerm_function_app.wvd_function[var.wvd_events["event_handler"]].id}/functions/Renew-RegistrationTokenAfterExpiration"
    max_events_per_batch              = 1
    preferred_batch_size_in_kilobytes = 64
  }
}