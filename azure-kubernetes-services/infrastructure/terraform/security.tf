## Creating an Azure Key Vault to store all secrets
resource "azurerm_key_vault" "dors_key_vault" {
  name                            = var.dors_key_vault_name
  location                        = azurerm_resource_group.dors_resource_group.location
  resource_group_name             = azurerm_resource_group.dors_resource_group.name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  purge_protection_enabled        = false
  enable_rbac_authorization       = true
  sku_name                        = "standard"
}

# ## Creating the managed system identity
# resource "azurerm_user_assigned_identity" "dors_msi" {
#   for_each            = var.dors_hostpool
#   name                = each.value.msi_name
#   resource_group_name = azurerm_resource_group.dors_resource_group.name
#   location            = azurerm_resource_group.dors_resource_group.location
# }

# ## Adding Managed Identity as Contributor and Key Vault Secrets Officer
# resource "azurerm_role_assignment" "dors_msi" {
#   count                = length(local.msi_roles)
#   role_definition_name = local.msi_roles[count.index].role
#   scope                = local.msi_roles[count.index].role != "Contributor" ? azurerm_key_vault.dors_key_vault.id : azurerm_resource_group.dors_resource_group.id
#   principal_id         = azurerm_user_assigned_identity.dors_msi[local.msi_roles[count.index].name].principal_id
# }

# ## Adding currently used Service Principal as Key Vault Secrets Officer
# resource "azurerm_role_assignment" "dors_sp" {
#   scope                = azurerm_key_vault.dors_key_vault.id
#   role_definition_name = "Key Vault Secrets Officer (preview)"
#   principal_id         = data.azurerm_client_config.current.object_id
# }