terraform {
  backend "azurerm" {
    resource_group_name  = "rg-prd-frc-tf-01"
    storage_account_name = "saprdfrctf01"
    container_name       = "windows-virtual-desktop"
    key                  = "prd-terraform.tfstate"
    subscription_id = ""
    client_id       = ""
    client_secret   = ""
    tenant_id       = ""
  }
}