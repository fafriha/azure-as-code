## Configuring Azure providers
provider "azurerm" {
    subscription_id = var.global_subscription_id
    client_id       = var.global_terraform_app["client_id"]
    client_secret   = var.global_terraform_app["client_secret"]
    tenant_id       = var.global_aad_tenant_id
    features {
        key_vault {
        purge_soft_delete_on_destroy = true
        }
    }
}

provider "azuread" {
  client_id     = var.global_terraform_app["client_id"]
  client_secret = var.global_terraform_app["client_secret"]
  tenant_id     = var.global_aad_tenant_id
}