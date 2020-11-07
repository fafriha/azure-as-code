## Getting the currently used service principal configuration
data "azurerm_client_config" "current" {}

## Getting the hub resource group
data "azurerm_resource_group" "hub" {
  name  = var.hub_resource_group_name
}

## Getting the hub virtual network
data "azurerm_virtual_network" "hub" {
  name                  = var.hub_virtual_network_name
  resource_group_name   = var.hub_resource_group_name
}
