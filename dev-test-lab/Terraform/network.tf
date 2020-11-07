## This virtual network will host all session hosts
resource "azurerm_dev_test_virtual_network" "lab" {
  name                = var.lab_virtual_network_name
  lab_name            = azurerm_dev_test_lab.lab.name
  resource_group_name = azurerm_resource_group.lab.name

  subnet {
    use_public_ip_address           = "Allow"
    use_in_virtual_machine_creation = "Allow"
  }
}

## This peering to the hub virtual network will allow session hosts to communicate with the domain controllers
resource "azurerm_virtual_network_peering" "lab" {
  name                      = var.lab_virtual_network_peering_name
  resource_group_name       = azurerm_resource_group.lab.name
  virtual_network_name      = azurerm_dev_test_virtual_network.lab.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub.id
  use_remote_gateways       = "true"
  allow_forwarded_traffic   = "true"
}

## This peering to the hub virtual network will allow session hosts to communicate with the domain controllers
resource "azurerm_virtual_network_peering" "hub" {
  name                      = var.hub_virtual_network_peering_name
  resource_group_name       = var.hub_resource_group_name
  virtual_network_name      = var.hub_virtual_network_name
  remote_virtual_network_id = azurerm_dev_test_virtual_network.lab.id
  use_remote_gateways       = "true"
  allow_forwarded_traffic   = "true"
}

## This subnet will host all Windows 10 session hosts
resource "azurerm_subnet" "lab" {
  name                 = var.lab_subnet_name
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_dev_test_virtual_network.lab.name
  address_prefix       = var.lab_subnet_address_prefix
}