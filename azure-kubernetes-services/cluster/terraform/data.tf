data "azurerm_resource_group" "core" {
  name  = "fabrikam-rg"
}

data "azurerm_virtual_network" "core" {
  name                = "fabrikam-vnet"
  resource_group_name = "fabrikam-rg"
}

data "azurerm_subnet" "core" {
  name                 = "Kubernetes"
  virtual_network_name = "fabrikam-vnet"
  resource_group_name  = "fabrikam-rg"
}