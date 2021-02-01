## Getting the currently used service principal configuration
data "azurerm_client_config" "current" {}

## Gathering hub resource group details
data "azurerm_resource_group" "hub_resource_group" {
  name = var.hub_resources["resource_group_name"]
}

## Gathering hub virtual network details
data "azurerm_virtual_network" "hub_virtual_network" {
  name                = var.hub_resources["virtual_network_name"]
  resource_group_name = var.hub_resources["resource_group_name"]
}

## Gathering hub route table details
#### Enable this block if you have a route table routing all traffic to a hub firewall
data "azurerm_route_table" "hub_route_table" {
  name                = var.hub_resources["default_route_table_name"]
  resource_group_name = var.hub_resources["resource_group_name"]
}