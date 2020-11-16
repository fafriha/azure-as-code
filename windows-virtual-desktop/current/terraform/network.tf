## Creating virtual network to host all session hosts
resource "azurerm_virtual_network" "wvd_virtual_network" {
  name                = var.wvd_networking["virtual_network_name"]
  address_space       = [var.wvd_networking["address_space"]]
  location            = azurerm_resource_group.wvd_resource_group.location
  resource_group_name = azurerm_resource_group.wvd_resource_group.name
  dns_servers         = data.azurerm_virtual_network.hub_virtual_network.dns_servers
}

## Peering between and hub's virtual network and WVD's virtual network 
resource "azurerm_virtual_network_peering" "hub_peering" {
  name                      = var.hub_resources["peering_name"]
  resource_group_name       = var.hub_resources["resource_group_name"]
  virtual_network_name      = var.hub_resources["virtual_network_name"]
  remote_virtual_network_id = azurerm_virtual_network.wvd_virtual_network.id
  allow_gateway_transit     = "false"
}

## Peering between WVD's virtual network and hub's virtual network 
resource "azurerm_virtual_network_peering" "wvd_peering" {
  name                      = var.wvd_networking["peering_name"]
  resource_group_name       = azurerm_resource_group.wvd_resource_group.name
  virtual_network_name      = azurerm_virtual_network.wvd_virtual_network.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_virtual_network.id
  use_remote_gateways       = "false"
  allow_forwarded_traffic   = "true"
}

## Creating a subnet to host all prouction session hosts
resource "azurerm_subnet" "wvd_clients" {
  name                 = var.wvd_networking["clients_subnet_name"]
  resource_group_name  = azurerm_resource_group.wvd_resource_group.name
  virtual_network_name = azurerm_virtual_network.wvd_virtual_network.name
  address_prefixes     = [var.wvd_networking["clients_subnet_address_prefix"]]
}

## Creating a subnet to host all canary session hosts
resource "azurerm_subnet" "wvd_canary" {
  name                 = var.wvd_networking["canary_subnet_name"]
  resource_group_name  = azurerm_resource_group.wvd_resource_group.name
  virtual_network_name = azurerm_virtual_network.wvd_virtual_network.name
  address_prefixes     = [var.wvd_networking["canary_subnet_address_prefix"]]
}

## Creating a subnet to host a Bastion instance
resource "azurerm_subnet" "wvd_bastion" {
  name                 = var.wvd_networking["bastion_subnet_name"]
  resource_group_name  = azurerm_resource_group.wvd_resource_group.name
  virtual_network_name = azurerm_virtual_network.wvd_virtual_network.name
  address_prefixes     = [var.wvd_networking["bastion_subnet_address_prefix"]]
}

## Creating a Public IP for the Bastion instance
resource "azurerm_public_ip" "wvd_bastion" {
  name                = var.wvd_networking["public_ip_name"]
  location            = azurerm_resource_group.wvd_resource_group.location
  resource_group_name = azurerm_resource_group.wvd_resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

## Creating all session hosts network interfaces
resource "azurerm_network_interface" "wvd_hosts" {
  for_each            = { for s in local.session_hosts : format("%s-%02d-01", s.vm_prefix, s.index + 1) => s }
  name                = "nic-${each.key}"
  location            = azurerm_resource_group.wvd_resource_group.location
  resource_group_name = azurerm_resource_group.wvd_resource_group.name

  ip_configuration {
    name                          = "ipc-${each.key}"
    subnet_id                     = var.wvd_hostpool[each.value.hostpool_name].validate_environment != "True" ? azurerm_subnet.wvd_clients.id : azurerm_subnet.wvd_canary.id
    private_ip_address_allocation = "dynamic"
  }
}