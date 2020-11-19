## Using an Azure Storage account as the Terraform backend
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-prd-frc-hub-01"
    storage_account_name = "saprdfrctf001"
    container_name       = "windows-virtual-desktop"
    key                  = "prd-terraform.tfstate"
    subscription_id = ""
    client_id       = ""
    client_secret   = ""
    tenant_id       = ""
  }
}