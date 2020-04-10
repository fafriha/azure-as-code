################################################### Hub ################################################

# resource "azurerm_virtual_network" "core" {
#   name                      = var.core_virtual_network_name
#   address_space             = [var.core_virtual_network_address_space]
#   location                  = azurerm_resource_group.core.location
#   resource_group_name       = azurerm_resource_group.core.name
#   #dns_servers               = [var.core_dns_servers]
# }

# resource "azurerm_virtual_network_peering" "core" {
#   name                      = var.core_virtual_network_peering_name
#   location                  = azurerm_resource_group.core.location
#   resource_group_name       = azurerm_resource_group.core.name
#   remote_virtual_network_id = azurerm_virtual_network.core.id
# }

# resource "azurerm_subnet" "core_subnet_identity" {
#   name                 = var.core_clients_subnet_name
#   resource_group_name  = azurerm_resource_group.core.name
#   virtual_network_name = azurerm_virtual_network.core.name
#   address_prefix       = var.core_clients_subnet_address_prefix
# }

# resource "azurerm_subnet" "core_subnet_shared_services" {
#   name                 = var.core_clients_subnet_name
#   resource_group_name  = azurerm_resource_group.core.name
#   virtual_network_name = azurerm_virtual_network.core.name
#   address_prefix       = var.core_clients_subnet_address_prefix
# }

# resource "azurerm_subnet" "core_subnet_bastion" {
#   name                 = var.core_clients_subnet_name
#   resource_group_name  = azurerm_resource_group.core.name
#   virtual_network_name = azurerm_virtual_network.core.name
#   address_prefix       = var.core_clients_subnet_address_prefix
# }

# resource "azurerm_public_ip" "core" {
#   name                = var.core_firewall_public_ip_name
#   location            = azurerm_resource_group.core.location
#   resource_group_name = azurerm_resource_group.core.name
#   allocation_method   = "Static"
#   sku                 = "Standard"
# }

# resource "azurerm_route_table" "core" {
#   name                          = "acceptanceTestSecurityGroup1"
#   location                      = azurerm_resource_group.core.location
#   resource_group_name           = azurerm_resource_group.core.name
#   disable_bgp_route_propagation = false

#   route {
#     name           = "route1"
#     address_prefix = "10.1.0.0/16"
#     next_hop_type  = "vnetlocal"
#   }

#   tags = {
#     environment = "Production"
#   }
# }

## This peering to the hub virtual network will allow domain controllers to communicate with all session hosts
resource "azurerm_virtual_network_peering" "hub" {
  name                      = var.hub_virtual_network_peering_name
  resource_group_name       = var.hub_resource_group_name
  virtual_network_name      = var.hub_virtual_network_name
  remote_virtual_network_id = azurerm_virtual_network.wvd.id
  allow_gateway_transit     = "true"
}

################################################### Windows Virtual Desktop ################################################

## This virtual network will host all session hosts
resource "azurerm_virtual_network" "wvd" {
  name                      = var.wvd_virtual_network_name
  address_space             = [var.wvd_virtual_network_address_space]
  location                  = azurerm_resource_group.wvd.location
  resource_group_name       = azurerm_resource_group.wvd.name
  dns_servers               = [var.wvd_dns_servers]
}

## This peering to the hub virtual network will allow session hosts to communicate with the domain controllers
resource "azurerm_virtual_network_peering" "wvd" {
  name                      = var.wvd_virtual_network_peering_name
  resource_group_name       = azurerm_resource_group.wvd.name
  virtual_network_name      = azurerm_virtual_network.wvd.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub.id
  use_remote_gateways       = "true"
  allow_forwarded_traffic   = "true"
}

## This subnet will host all Windows 10 session hosts
resource "azurerm_subnet" "wvd_subnet_clients" {
  name                 = var.wvd_clients_subnet_name
  resource_group_name  = azurerm_resource_group.wvd.name
  virtual_network_name = azurerm_virtual_network.wvd.name
  address_prefix       = var.wvd_clients_subnet_address_prefix
}

## This subnet will host the Azure Bastion instance
resource "azurerm_subnet" "wvd_subnet_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.wvd.name
  virtual_network_name = azurerm_virtual_network.wvd.name
  address_prefix       = var.wvd_subnet_bastion_address_prefix
}

## This public ip will be affected to the Azure Bastion instance
resource "azurerm_public_ip" "wvd" {
  name                = var.wvd_public_ip_name
  location            = azurerm_resource_group.wvd.location
  resource_group_name = azurerm_resource_group.wvd.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

## Each session host will have a single network interface
resource "azurerm_network_interface" "wvd" {
  count                     = var.wvd_rdsh_count
  name                      = "nic-azprd-frc-${var.wvd_vm_prefix}0${count.index+1}-0${count.index+1}"
  location                  = azurerm_resource_group.wvd.location
  resource_group_name       = azurerm_resource_group.wvd.name

  ip_configuration {
    name                          = "ipc-azprd-frc-${var.wvd_vm_prefix}0${count.index+1}-0${count.index+1}"
    subnet_id                     = azurerm_subnet.wvd_subnet_clients.id
    private_ip_address_allocation = "dynamic"
  }
}