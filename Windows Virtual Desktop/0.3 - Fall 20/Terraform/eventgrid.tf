## 
resource "azurerm_eventgrid_topic" "wvd" {
  name                = "my-eventgrid-topic"
  location            = azurerm_resource_group.wvd.location
  resource_group_name = azurerm_resource_group.wvd.name
}

## 
resource "azurerm_eventgrid_event_subscription" "wvd" {
  name  = "defaultEventSubscription"
  scope = azurerm_resource_group.default.id
  event_delivery_schema = "EventGridSchema"
  topic_name = "my-eventgrid-topic"

  azure_function_endpoint {
    function_id = "${azurerm_eventhub.test.id}"
  }
}