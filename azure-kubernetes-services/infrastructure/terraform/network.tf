## Creating virtual network to host all session hosts
resource "azurerm_virtual_network" "dors_virtual_network" {
  name                = var.dors_virtual_network["virtual_network_name"]
  address_space       = [var.dors_virtual_network["address_space"]]
  location            = azurerm_resource_group.dors_resource_group.location
  resource_group_name = azurerm_resource_group.dors_resource_group.name
  dns_servers         = data.azurerm_virtual_network.hub_virtual_network.dns_servers
}

## Peering between hub's virtual network and Dors' virtual network 
resource "azurerm_virtual_network_peering" "hub_peering" {
  name                      = var.hub_resources["peering_name"]
  resource_group_name       = var.hub_resources["resource_group_name"]
  virtual_network_name      = var.hub_resources["virtual_network_name"]
  remote_virtual_network_id = azurerm_virtual_network.dors_virtual_network.id
  allow_gateway_transit     = "true"
  allow_forwarded_traffic   = "true"
}

## Peering between Dors' virtual network and hub's virtual network 
resource "azurerm_virtual_network_peering" "dors_peering" {
  name                      = var.dors_virtual_network["peering_name"]
  resource_group_name       = azurerm_resource_group.dors_resource_group.name
  virtual_network_name      = azurerm_virtual_network.dors_virtual_network.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_virtual_network.id
  use_remote_gateways       = "true"
  allow_forwarded_traffic   = "false"
}

## Creating all subnets to host all nodes
resource "azurerm_subnet" "dors_subnets" {
  for_each             = var.dors_subnets
  name                 = each.value.subnet_name
  resource_group_name  = azurerm_resource_group.dors_resource_group.name
  virtual_network_name = azurerm_virtual_network.dors_virtual_network.name
  address_prefixes     = [each.value.address_prefix]
}

## Associating hub's route table to clients and canary subnets
resource "azurerm_subnet_route_table_association" "dors_routing" {
  for_each       = azurerm_subnet.dors_subnets
  subnet_id      = each.value.id
  route_table_id = data.azurerm_route_table.hub_route_table.id
}