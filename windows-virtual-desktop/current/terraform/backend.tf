terraform {
  backend "azurerm" {
    resource_group_name  = var.tf_backend["resource_group_name"]
    storage_account_name = var.tf_backend["storage_account_name"]
    container_name       = var.tf_backend["container_name"]
    key                  = var.tf_backend["blob_name"]
  }
}