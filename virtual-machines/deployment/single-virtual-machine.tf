variable "local_admin_account" {
  description = "Please provide the required information for the local administrator account."
  type        = map(string)
  default = {
    "username" = "superduperuser"
    "password" = "P@ssword1"
  }
}

variable "terraform_sp" {
  description = "Please provide the required information about your existing Terraform Service Principal."
  type        = map(string)
  default = {
    "client_id"     = ""
    "client_secret" = ""
  }
}

variable "aad_tenant_id" {
  description = "Please provide the ID of your existing Azure AD tenant."
  default     = ""
}

variable "subscription_id" {
  description = "Please provide the ID of your existing subscription."
  default     = ""
}

variable "storage" {
  description = "[Mandatory] [Create] Enter the name of the storage account that will host all user profiles."
  type        = map(string)
  default = {
    "function_account_name" = "saprdfrcwvd01"
    "function_account_kind" = "StorageV2"
    "function_account_tier" = "Standard"
    "profiles_account_name" = "saprdfrcwvd02"
    "profiles_account_kind" = "FileStorage"
    "profiles_account_tier" = "Premium"
    "replication_type"      = "LRS"
    "enable_https"          = "true"
  }
}

provider "azurerm" {
    subscription_id = var.subscription_id
    client_id       = var.terraform_sp["client_id"]
    client_secret   = var.terraform_sp["client_secret"]
    tenant_id       = var.aad_tenant_id
    features{}
}

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
  required_version = ">= 0.13"
}

resource "azurerm_resource_group" "contoso" {
  name     = "rg-prd-frc-contoso-01"
  location = "francecentral"
}

resource "azurerm_virtual_network" "contoso" {
  name                = "vnet-prd-frc-contoso-01"
  address_space       = ["192.168.2.0/24"]
  location            = azurerm_resource_group.contoso.location
  resource_group_name = azurerm_resource_group.contoso.name
}

resource "azurerm_subnet" "contoso" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.contoso.name
  virtual_network_name = azurerm_virtual_network.contoso.name
  address_prefixes     = ["192.168.2.0/24"]
}

resource "azurerm_network_interface" "contoso" {
  name                = "contoso-nic"
  location            = azurerm_resource_group.contoso.location
  resource_group_name = azurerm_resource_group.contoso.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.contoso.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "contoso" {
  name                = "vm-contoso-01"
  resource_group_name = azurerm_resource_group.contoso.name
  location            = azurerm_resource_group.contoso.location
  size                = "Standard_F2"
  admin_username      = var.local_admin_account["username"]
  admin_password      = var.local_admin_account["password"]
  network_interface_ids = [
    azurerm_network_interface.contoso.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "office-365"
    sku       = "20h2-evd-o365pp"
    version   = "latest"
  }
}

resource "azurerm_storage_account" "contoso" {
  name                      = var.storage["profiles_account_name"]
  location                  = azurerm_resource_group.contoso.location
  resource_group_name       = azurerm_resource_group.contoso.name
  account_kind              = var.storage["profiles_account_kind"]
  account_tier              = var.storage["profiles_account_tier"]
  account_replication_type  = var.storage["replication_type"]
  enable_https_traffic_only = var.storage["enable_https"]
}

resource "azurerm_storage_share" "contoso" {
  name                 = "fileshare"
  storage_account_name = azurerm_storage_account.contoso.name
  quota                = 5120
}

resource "azurerm_virtual_machine_extension" "contoso" {
  name                 = "JoinHostpool"
  virtual_machine_id   = azurerm_windows_virtual_machine.contoso.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  protected_settings = <<PROTECTED_SETTINGS
    {
      "script": "${base64encode(templatefile("./Install-Agents.ps1", { 
                                                FileShare = "${replace(replace("${azurerm_storage_share.contoso.url}", "https:", ""), "/", "\\")}", 
                                                RegistrationToken = "Token", 
                                                LocalAdminName = "${var.local_admin_account["username"]}"}))}"
    }
  PROTECTED_SETTINGS
}