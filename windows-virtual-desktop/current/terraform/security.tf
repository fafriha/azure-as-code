## Creating a network security group to secure session hosts (should be disabled if already using a Bastion in a hub)
resource "azurerm_network_security_group" "wvd_network_security_group" {
  name                = var.wvd_virtual_network["network_security_group_name"]
  location            = azurerm_resource_group.wvd_resource_group.location
  resource_group_name = azurerm_resource_group.wvd_resource_group.name
}

## Creating a security rule to allow Bastion traffic to canary hosts (should be disabled if already using a Bastion in a hub)
resource "azurerm_network_security_rule" "wvd_allow_bastion" {
  name                        = "AllowInboundFromHub"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = data.azurerm_virtual_network.hub_virtual_network.address_space
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.wvd_resource_group.name
  network_security_group_name = azurerm_network_security_group.wvd_network_security_group.name
}

## Creating a basic network security group to deny all inboud traffic to production hosts (should be disabled if already using a Bastion in a hub)
resource "azurerm_network_security_rule" "wvd_deny_all" {
  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.wvd_resource_group.name
  network_security_group_name = azurerm_network_security_group.wvd_network_security_group.name
}

## Associating the network security group with subnets hosting session hosts
resource "azurerm_subnet_network_security_group_association" "wvd_deny_inbound_traffic" {
  for_each                  = azurerm_subnet.wvd_subnets
  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.wvd_network_security_group.id
}

## Creating an Azure Key Vault to store all secrets
resource "azurerm_key_vault" "wvd_key_vault" {
  name                            = var.wvd_key_vault_name
  location                        = azurerm_resource_group.wvd_resource_group.location
  resource_group_name             = azurerm_resource_group.wvd_resource_group.name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  soft_delete_enabled             = false
  purge_protection_enabled        = false
  enable_rbac_authorization       = true
  sku_name                        = "standard"
}

## Creating the managed service identity
resource "azurerm_user_assigned_identity" "wvd_msi" {
  for_each            = var.wvd_msi_roles
  name                = each.value.name
  resource_group_name = azurerm_resource_group.wvd_resource_group.name
  location            = azurerm_resource_group.wvd_resource_group.location
}

## Adding Managed Identity as Contributor and Key Vault Secrets Officer
resource "azurerm_role_assignment" "wvd_msi" {
  for_each             = { for msi in local.msi_roles : msi.role => msi... }
  role_definition_name = each.key
  scope                = each.key != "Contributor" ? azurerm_key_vault.wvd_key_vault.id : azurerm_resource_group.wvd_resource_group.id
  principal_id         = azurerm_user_assigned_identity.wvd_msi[each.value.name].id
}

## Adding users to application groups
#### WARNING - Adding users to application groups requires User Access Administrator or Owner rights and Reader rights on Azure AD
resource "azurerm_role_assignment" "wvd_users" {
  count                = length(local.application_groups)
  scope                = azurerm_virtual_desktop_application_group.wvd_application_group[local.application_groups[count.index].name].id
  role_definition_name = "Desktop virtualization user"
  principal_id         = data.azuread_user.wvd_users[local.application_groups[count.index].user].id
}

output msis{
  value = azurerm_user_assigned_identity.wvd_msi.indentity[0]
}

## Adding currently used Service Principals as Key Vault Secrets Officer
resource "azurerm_role_assignment" "wvd_sp" {
  scope                = azurerm_key_vault.wvd_key_vault.id
  role_definition_name = "Key Vault Secrets Officer (preview)"
  principal_id         = data.azurerm_client_config.current.object_id
}

## Securing local admin account details
resource "azurerm_key_vault_secret" "wvd_local_admin_account" {
  name         = var.wvd_local_admin_account["username"]
  value        = var.wvd_local_admin_account["password"]
  key_vault_id = azurerm_key_vault.wvd_key_vault.id
  depends_on   = [azurerm_role_assignment.wvd_sp]
}

## Securing domain join account details
resource "azurerm_key_vault_secret" "wvd_domain_join_account" {
  name         = var.wvd_domain_join_account["username"]
  value        = var.wvd_domain_join_account["password"]
  key_vault_id = azurerm_key_vault.wvd_key_vault.id
  depends_on   = [azurerm_role_assignment.wvd_sp]
}

## Securing hostpool registration token
resource "azurerm_key_vault_secret" "wvd_registration_info" {
  for_each     = var.wvd_hostpool
  name         = each.value.name
  value        = azurerm_virtual_desktop_host_pool.wvd_hostpool[each.value.name].registration_info[0].token
  key_vault_id = azurerm_key_vault.wvd_key_vault.id
  depends_on   = [azurerm_role_assignment.wvd_sp]
}