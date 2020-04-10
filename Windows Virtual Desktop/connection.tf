## Configuring the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = var.subscription_id
    client_id       = var.terraform_app_client_id
    client_secret   = var.terraform_app_client_secret
    tenant_id       = var.aad_tenant_id
    features {}
}