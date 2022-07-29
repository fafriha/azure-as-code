## Creating a virtual network with at least one subnet to host session hosts
resource "azurerm_virtual_network" "avd_virtual_networks" {
  for_each            = { for hp in var.avd_hostpools : hp.name => hp }
  name                = each.value.virtual_network_name
  address_space       = [each.value.address_space]
  location            = azurerm_resource_group.avd_rgs["network"].location
  resource_group_name = azurerm_resource_group.avd_rgs["network"].name
  dns_servers         = var.hub_network_resources["dns_servers_ip"]

  subnet {
    name           = each.value.subnet_name
    address_prefix = each.value.address_prefix
    security_group = azurerm_network_security_group.avd_nsgs[each.key].id
  }
}

## Creating all session hosts network interfaces
resource "azurerm_network_interface" "avd_nics" {
  for_each            = { for host in local.session_hosts : format("nic-%03d-%s-%03d", host.index + 1, host.vm_prefix, host.index + 1) => host }
  name                = each.key
  location            = azurerm_resource_group.avd_rgs["compute"].location
  resource_group_name = azurerm_resource_group.avd_rgs["compute"].name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_virtual_network.avd_virtual_networks[each.value.hostpool_name].subnet.*.id[0]
    private_ip_address_allocation = "Dynamic"
  }
}

#### Private endpoints ####
## Storage account

## Key Vault


#### In cas of traditional Azure networking topology
## Peering between spoke's virtual network and hub's virtual network
## Peering AVD's virtual network to Virtual Hub 
# resource "azurerm_virtual_network_peering" "avd_peering" {
#   name                      = var.avd_virtual_network["peering_name"]
#   location                         = azurerm_resource_group.avd_rgs["network"].location
#   resource_group_name              = azurerm_resource_group.avd_rgs["network"].name
#   remote_virtual_network_id = data.azurerm_virtual_network.hub_virtual_network.id
#   use_remote_gateways       = "true"
#   allow_forwarded_traffic   = "false"
# }

# ## Creating a route table to route all trafic to the Hub's Azure Firewall
# resource "azurerm_route_table" "avd_routing" {
#   name                          = var.avd_virtual_network.route_table
#   location                      = azurerm_resource_group.avd_resource_group.location
#   resource_group_name           = azurerm_resource_group.avd_resource_group.name
#   disable_bgp_route_propagation = false

#   route {
#     name           = "ToFirewall"
#     address_prefix = var.avd_virtual_network.address_space
#     next_hop_type  = "VirtualAppliance"
#   }
# }

# ## Associating the route table to all AVD subnets
# resource "azurerm_subnet_route_table_association" "avd_routing" {
#   for_each       = azurerm_subnet.avd_subnets
#   subnet_id      = each.value.id
#   route_table_id = data.azurerm_route_table.hub_route_table.id
# }

#### In case of Virtual WAN network topology
## Connecting virtual hub and AVD's virtual network
resource "azurerm_virtual_hub_connection" "avd_virtual_hub_connections" {
  for_each                  = { for hp in var.avd_hostpools : hp.name => hp }
  provider                  = azurerm.hub
  name                      = "connection-avd-${azurerm_resource_group.avd_rgs["network"].location}-prefix-random"
  virtual_hub_id            = data.azurerm_virtual_hub.hub_virtual_hub.id
  remote_virtual_network_id = azurerm_virtual_network.avd_virtual_networks[each.key].id
}