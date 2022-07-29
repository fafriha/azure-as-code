## Creating a network security group to secure session hosts (should be disabled if already using a Bastion in a hub)
resource "azurerm_network_security_group" "avd_nsgs" {
  for_each            = { for hp in var.avd_hostpools : hp.name => hp }
  name                = each.value.network_security_group_name
  location            = azurerm_resource_group.avd_rgs["compute"].location
  resource_group_name = azurerm_resource_group.avd_rgs["compute"].name
}

resource "azurerm_network_security_rule" "avd_deny_all" {
  for_each                    = azurerm_network_security_group.avd_nsgs
  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  resource_group_name         = each.value.name
  network_security_group_name = each.value.name
}

## Creating an Azure Key Vault to store all secrets
resource "azurerm_key_vault" "avd_key_vault" {
  name                            = var.avd_key_vault_name
  location                        = azurerm_resource_group.avd_rgs["service-objects"].location
  resource_group_name             = azurerm_resource_group.avd_rgs["service-objects"].name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  enabled_for_deployment          = true
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  purge_protection_enabled        = false
  enable_rbac_authorization       = true
  sku_name                        = "standard"
}

## Creating the managed system identities
resource "azurerm_user_assigned_identity" "avd_msis" {
  for_each            = { for hp in var.avd_hostpools : hp.name => hp }
  name                = each.key
  location            = azurerm_resource_group.avd_rgs["service-objects"].location
  resource_group_name = azurerm_resource_group.avd_rgs["service-objects"].name
}

## Adding managed identities as Contributor and Key Vault Secrets Officer
resource "azurerm_role_assignment" "avd_contributor" {
  for_each                         = azurerm_user_assigned_identity.avd_msis
  role_definition_name             = "Contributor"
  scope                            = azurerm_resource_group.avd_rgs["service-objects"].id
  principal_id                     = each.value.principal_id
  skip_service_principal_aad_check = "true"
}

resource "azurerm_role_assignment" "avd_key_vault_secret_officer" {
  for_each                         = azurerm_user_assigned_identity.avd_msis
  role_definition_name             = "Key Vault Secret Officer"
  scope                            = azurerm_key_vault.avd_key_vault.id
  principal_id                     = each.value.principal_id
  skip_service_principal_aad_check = "true"
}

## Adding users to application groups
#### WARNING - Adding users to application groups requires User Access Administrator or Owner rights and Reader rights on Azure AD
resource "azurerm_role_assignment" "avd_users" {
  count                = length(local.application_groups)
  scope                = azurerm_virtual_desktop_application_group.avd_application_groups[local.application_groups[count.index].name].id
  role_definition_name = "Desktop virtualization user"
  principal_id         = data.azuread_user.avd_users[local.application_groups[count.index].user].id
}

## Adding currently used Service Principal as Key Vault Secrets Officer
resource "azurerm_role_assignment" "avd_sp" {
  scope                = azurerm_key_vault.avd_key_vault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

## Securing account details
resource "azurerm_key_vault_secret" "avd_accounts" {
  for_each     = var.hub_identity_resources["accounts"]
  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.avd_key_vault.id
  depends_on   = [azurerm_role_assignment.avd_sp]
}

## Securing hostpool registration token
resource "azurerm_key_vault_secret" "avd_registration_tokens" {
  for_each     = { for hp in var.avd_hostpools : hp.name => hp }
  name         = each.value.name
  value        = azurerm_virtual_desktop_host_pool_registration_info.avd_registration_info[azurerm_virtual_desktop_host_pool.avd_hostpools[each.value.name].id].token
  key_vault_id = azurerm_key_vault.avd_key_vault.id
  depends_on   = [azurerm_role_assignment.avd_sp]
}

## Creating application security groups
resource "azurerm_application_security_group" "avd_asgs" {
  for_each            = { for hp in var.avd_hostpools : hp.name => hp }
  name                = each.value.application_security_group_name
  location            = azurerm_resource_group.avd_rgs["compute"].location
  resource_group_name = azurerm_resource_group.avd_rgs["compute"].name
}

## Association application security groups with network interfaces
resource "azurerm_network_interface_application_security_group_association" "avd_asg_nic_asociation" {
  for_each                      = { for host in local.session_hosts : format("nic-%03d-%s-%03d", host.index + 1, host.vm_prefix, host.index + 1) => host }
  network_interface_id          = azurerm_network_interface.avd_nics[each.key].id
  application_security_group_id = azurerm_application_security_group.avd_asgs[each.value.hostpool_name].id
}