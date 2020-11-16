## Configuring Azure RM provider
provider "azurerm" {
  subscription_id = var.subscription_id
  client_id       = var.terraform_sp["client_id"]
  client_secret   = var.terraform_sp["client_secret"]
  tenant_id       = var.aad_tenant_id
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

## Configuring Azure AD provider
provider "azuread" {
  client_id     = var.terraform_sp["client_id"]
  client_secret = var.terraform_sp["client_secret"]
  tenant_id     = var.aad_tenant_id
}