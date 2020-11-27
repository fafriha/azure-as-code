## Creating virtual network to host all session hosts
resource "azurerm_virtual_network" "wvd_virtual_network" {
  name                = var.wvd_virtual_network["virtual_network_name"]
  address_space       = [var.wvd_virtual_network["address_space"]]
  location            = azurerm_resource_group.wvd_resource_group.location
  resource_group_name = azurerm_resource_group.wvd_resource_group.name
  dns_servers         = data.azurerm_virtual_network.hub_virtual_network.dns_servers
}

## Peering between hub's virtual network and WVD's virtual network 
resource "azurerm_virtual_network_peering" "hub_peering" {
  name                      = var.hub_resources["peering_name"]
  resource_group_name       = var.hub_resources["resource_group_name"]
  virtual_network_name      = var.hub_resources["virtual_network_name"]
  remote_virtual_network_id = azurerm_virtual_network.wvd_virtual_network.id
  allow_gateway_transit     = "true"
  allow_forwarded_traffic   = "true"
}

## Peering between WVD's virtual network and hub's virtual network 
resource "azurerm_virtual_network_peering" "wvd_peering" {
  name                      = var.wvd_virtual_network["peering_name"]
  resource_group_name       = azurerm_resource_group.wvd_resource_group.name
  virtual_network_name      = azurerm_virtual_network.wvd_virtual_network.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_virtual_network.id
  use_remote_gateways       = "true"
  allow_forwarded_traffic   = "false"
}

## Creating all subnets to host all session hosts
resource "azurerm_subnet" "wvd_subnets" {
  for_each             = var.wvd_subnets
  name                 = each.value.subnet_name
  resource_group_name  = azurerm_resource_group.wvd_resource_group.name
  virtual_network_name = azurerm_virtual_network.wvd_virtual_network.name
  address_prefixes     = [each.value.address_prefix]
}

## Associating hub's route table to clients and canary subnets
resource "azurerm_subnet_route_table_association" "wvd_routing" {
  for_each       = azurerm_subnet.wvd_subnets
  subnet_id      = each.value.id
  route_table_id = data.azurerm_route_table.hub_route_table.id
}

## Creating all session hosts network interfaces
resource "azurerm_network_interface" "wvd_hosts" {
  for_each            = { for s in local.session_hosts : format("%s-%02d", s.vm_prefix, s.index + 1) => s }
  name                = "nic-${each.key}"
  location            = azurerm_resource_group.wvd_resource_group.location
  resource_group_name = azurerm_resource_group.wvd_resource_group.name

  ip_configuration {
    name                          = "ipc-${each.key}"
    subnet_id                     = azurerm_subnet.wvd_subnets[replace(each.value.hostpool_name, "hp", "snet")].id
    private_ip_address_allocation = "dynamic"
  }
}