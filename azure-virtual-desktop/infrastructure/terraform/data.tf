## Getting the currently used service principal configuration
data "azurerm_client_config" "current" {}

## Gathering application groups members details
### WARNING - Adding users to application groups required User Access Administrator or Owner rights and Reader rights on Azure AD
data "azuread_user" "avd_users" {
  for_each            = toset([for u in local.application_groups : u.user])
  user_principal_name = each.key
}

## Gathering hub resource group details
data "azurerm_resource_group" "hub_identity_rg" {
  provider = azurerm.identity
  name     = var.hub_identity_resources["core"].resource_group_name
}

## Gathering hub resource group details
data "azurerm_resource_group" "hub_network_rg" {
  provider = azurerm.hub
  name     = var.hub_network_resources["resource_group_name"]
}

## Gathering virtual hub details
data "azurerm_virtual_hub" "hub_virtual_hub" {
  provider            = azurerm.hub
  name                = var.hub_network_resources["virtual_hub_name"]
  resource_group_name = var.hub_network_resources["resource_group_name"]
}

## Gathering hub route table details
#### Enable this block if you have a route table routing all traffic to a hub firewall
# data "azurerm_route_table" "hub_route_table" {
#   name                = var.hub_resources["default_route_table_name"]
#   resource_group_name = var.hub_resources["resource_group_name"]
# }

# ## Gathering managed image details
# #### Enable this if you are using a managed image to create session hosts
# data "azurerm_image" "avd" {
#   name                    = "windows10-img"
#   resource_group_name     = azurerm_resource_group.avd.name
# }