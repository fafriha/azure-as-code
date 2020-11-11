terraform {
  backend "azurerm" {
    resource_group_name  = "rg-prd-frc-tf-01"
    storage_account_name = "saprdfrctf01"
    container_name       = "windows-virtual-desktop"
    key                  = "prd-terraform.tfstate"
    subscription_id = var.subscription_id
    client_id       = var.terraform_sp["client_id"]
    client_secret   = var.terraform_sp["client_secret"]
    tenant_id       = var.aad_tenant_id
  }
}