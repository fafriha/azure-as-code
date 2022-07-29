## Configuring Azure RM provider
provider "azurerm" {
  alias           = "hub"
  subscription_id = "499ebb15-4491-4637-885b-4da10ea1e049"
  #use_msi         = true
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

provider "azurerm" {
  alias           = "identity"
  subscription_id = "975aa103-7fd4-4050-afa3-08eac33a7d3a"
  #use_msi         = true
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

provider "azurerm" {
  #use_msi         = true
  #alias           = "avd"
  subscription_id = "eab21f26-4a6c-4db5-97ff-77c1ed7c6f85"
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

## Configuring Azure AD provider
provider "azuread" {
  #use_msi   = true
}