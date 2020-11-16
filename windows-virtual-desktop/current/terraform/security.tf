## Creating a network security group to secure session hosts (should be disabled if already using a Bastion in a hub)
resource "azurerm_network_security_group" "wvd_network_security_group" {
  name                = var.wvd_networking["network_security_group_name"]
  location            = azurerm_resource_group.wvd_resource_group.location
  resource_group_name = azurerm_resource_group.wvd_resource_group.name
}

## Creating a security rule to allow Bastion traffic to canary hosts (should be disabled if already using a Bastion in a hub)
resource "azurerm_network_security_rule" "wvd_allow_bastion" {
  name                        = "AllowAzureBastionInbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = azurerm_subnet.wvd_bastion.address_prefix
  destination_address_prefix  = azurerm_subnet.wvd_canary.address_prefix
  resource_group_name         = azurerm_resource_group.wvd_resource_group.name
  network_security_group_name = azurerm_network_security_group.wvd_network_security_group.name
}

## Creating a basic network security group to deny all inboud traffic to production hosts (should be disabled if already using a Bastion in a hub)
resource "azurerm_network_security_rule" "wvd_deny_all" {
  name                        = "DenyAllInbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.wvd_resource_group.name
  network_security_group_name = azurerm_network_security_group.wvd_network_security_group.name
}

## Associating the network security group with subnets hosting session hosts
resource "azurerm_subnet_network_security_group_association" "none" {
  subnet_id                 = azurerm_subnet.wvd_clients.id
  network_security_group_id = azurerm_network_security_group.wvd_network_security_group.id
}

## Associating the network security group with subnets hosting session hosts
resource "azurerm_subnet_network_security_group_association" "none" {
  subnet_id                 = azurerm_subnet.wvd_canary.id
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

## Securing hostpools registration tokens
resource "azurerm_key_vault_secret" "wvd_registration_info" {
  for_each     = var.wvd_hostpool
  name         = each.value.name
  value        = azurerm_virtual_desktop_host_pool.wvd_hostpool[each.value.name].registration_info[0].token
  key_vault_id = azurerm_key_vault.wvd_key_vault.id
  depends_on   = [azurerm_role_assignment.wvd_sp]
}

## Creating a Bastion instance
resource "azurerm_bastion_host" "wvd_bastion" {
  name                = var.wvd_networking["bastion_name"]
  location            = azurerm_resource_group.wvd_resource_group.location
  resource_group_name = azurerm_resource_group.wvd_resource_group.name

  ip_configuration {
    name                 = "ipc-azprd-frc-${var.wvd_networking["bastion_name"]}"
    subnet_id            = azurerm_subnet.wvd_bastion.id
    public_ip_address_id = azurerm_public_ip.wvd_bastion.id
  }
}

## Adding MSIs as Contributor and Key Vault Secrets Officer
resource "azurerm_role_assignment" "wvd_sp" {
  count                = length(local.sp_roles)
  scope                = local.sp_roles[count.index].role != "Contributor" ? azurerm_key_vault.wvd_key_vault.id : azurerm_resource_group.wvd_resource_group.id
  role_definition_name = local.sp_roles[count.index].role
  principal_id         = local.sp_roles[count.index].name != "Terraform Service Principal" ? azurerm_function_app.wvd_function[local.sp_roles[count.index].name].identity.0.principal_id : data.azurerm_client_config.current.object_id
}

# ## Adding users to application groups
# #### WARNING - Adding users to application groups required User Access Administrator or Owner rights
# resource "azurerm_role_assignment" "wvd_users" {
#   count                = length(local.application_groups)
#   scope                = azurerm_virtual_desktop_application_group.wvd_application_group[local.application_groups[count.index].name].id
#   role_definition_name = "Desktop virtualization user"
#   principal_id         = data.azuread_user.wvd_users[local.application_groups[count.index].user].id
# }