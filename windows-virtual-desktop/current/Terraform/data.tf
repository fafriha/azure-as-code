################################################### Production & Canary ################################################
## Getting the currently used service principal configuration
data "azurerm_client_config" "current" {}

data "azuread_user" "wvd" {
  for_each            = toset([for u in local.application_groups : u.user])
  user_principal_name = each.key
  }

## Getting the hub resource group
data "azurerm_resource_group" "hub" {
  name  = var.hub_resource_group_name
}

## Getting the hub virtual network
data "azurerm_virtual_network" "hub" {
  name                  = var.hub_virtual_network["name"]
  resource_group_name   = var.hub_resource_group_name
}

### Getting the hub route table
data "azurerm_route_table" "hub" {
  name                = var.wvd_virtual_network["default_route_table_name"]
  resource_group_name = var.hub_resource_group_name
}

# data "azurerm_image" "wvd" {
#   name                    = "windows10-img"
#   resource_group_name     = azurerm_resource_group.wvd.name
# }