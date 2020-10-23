################################################### Windows Virtual Desktop ################################################

## This network security group will secure all session hosts
resource "azurerm_network_security_group" "wvd" {
  name                = var.wvd_network_security_group_name
  location            = azurerm_resource_group.wvd.location
  resource_group_name = azurerm_resource_group.wvd.name

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

## The network security group created above will be associated to the subnet hosting all session hosts
resource "azurerm_subnet_network_security_group_association" "wvd" {
  subnet_id                 = azurerm_subnet.wvd_clients.id
  network_security_group_id = azurerm_network_security_group.wvd.id
}

## This key vault will store all secrets related to Windows Virtual Desktop
resource "azurerm_key_vault" "wvd" {
  name                            = var.wvd_key_vault_name
  location                        = azurerm_resource_group.wvd.location
  resource_group_name             = azurerm_resource_group.wvd.name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  soft_delete_enabled             = false
  purge_protection_enabled        = false
  enable_rbac_authorization       = true
  sku_name                        = "standard"
}

## The sessions hosts local administrator account will be secured as a key vault secret
resource "azurerm_key_vault_secret" "wvd_local_admin_account" {
  name         = var.wvd_local_admin_account["username"]
  value        = var.wvd_local_admin_account["password"]
  key_vault_id = azurerm_key_vault.wvd.id
  depends_on   = [azurerm_role_assignment.wvd_sp]
}

## The domain join service account will be secured as a key vault secret
resource "azurerm_key_vault_secret" "wvd_domain_join_account" {
  name         = var.wvd_domain_join_account["username"]
  value        = var.wvd_domain_join_account["password"]
  key_vault_id = azurerm_key_vault.wvd.id
  depends_on   = [azurerm_role_assignment.wvd_sp]
}

# ## The registration token will be secured as a key vault secret
# resource "azurerm_key_vault_secret" "wvd_registration_info" {
#   for_each     = var.wvd_host_pools
#   name         = each.value.name
#   value        = azurerm_virtual_desktop_host_pool.wvd[each.value.name].registration_info[0].token
#   key_vault_id = azurerm_key_vault.wvd.id
#   depends_on   = [azurerm_role_assignment.wvd_sp]
# }

# ## The bastion host will secure RDP connections to all session hosts
# resource "azurerm_bastion_host" "wvd_bastion" {
#   name                = var.wvd_bastion_name
#   location            = azurerm_resource_group.wvd.location
#   resource_group_name = azurerm_resource_group.wvd.name

#   ip_configuration {
#     name                 = "ipc-azprd-frc-${var.wvd_bastion_name}"
#     subnet_id            = azurerm_subnet.wvd_bastion.id
#     public_ip_address_id = azurerm_public_ip.wvd_bastion.id
#   }
# }

## Adding MSIs as Contributor and Key Vault Secrets Officer
resource "azurerm_role_assignment" "wvd_sp" {
  count                = length(local.sp_roles)
  scope                = local.sp_roles[count.index].role != "Contributor" ? azurerm_key_vault.wvd.id : azurerm_resource_group.wvd.id
  role_definition_name = local.sp_roles[count.index].role
  principal_id         = local.sp_roles[count.index].name != "Terraform Service Principal" ? azurerm_function_app.wvd[local.sp_roles[count.index].name].identity[0].principal_id : data.azurerm_client_config.current.object_id
}

## Adding users to application groups
resource "azurerm_role_assignment" "wvd_users" {
  count                = length(local.application_groups)
  scope                = azurerm_virtual_desktop_application_group.wvd[local.application_groups[count.index].name].id
  role_definition_name = "Desktop virtualization user"
  principal_id         = data.azuread_user.wvd[local.application_groups[count.index].user].id
}