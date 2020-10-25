## Configuring the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = var.global_subscription_id
    client_id       = var.global_terraform_app_id
    client_secret   = var.global_terraform_app_secret
    tenant_id       = var.global_aad_tenant_id
    features {
        key_vault {
        purge_soft_delete_on_destroy = true
        }
    }
}