## Using an Azure Storage account as the Terraform backend
terraform {
  backend "azurerm" {
    resource_group_name  = "storage-rg"
    storage_account_name = "ststateterraform001"
    container_name       = "azure-virtual-desktop"
    key                  = "terraform.tfstate"
  }
}