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
  soft_delete_enabled             = true
  purge_protection_enabled        = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "get",
      "set",
      "list",
      "delete"
    ]
  }
}

## The terraform service principal will be secured as a key vault secret
resource "azurerm_key_vault_secret" "global_terraform_app" {
  name         = var.global_terraform_app_id
  value        = var.global_terraform_app_secret
  key_vault_id = azurerm_key_vault.wvd.id
}

## The Windows Virtual Desktop tenant service principal will be secured as a key vault secret
resource "azurerm_key_vault_secret" "wvd_tenant_app" {
  name         = var.wvd_tenant_app_id
  value        = var.wvd_tenant_app_secret
  key_vault_id = azurerm_key_vault.wvd.id
}

## The sessions hosts local administrator account will be secured as a key vault secret
resource "azurerm_key_vault_secret" "wvd_local_admin_account" {
  name         = var.wvd_local_admin_username
  value        = var.wvd_local_admin_password
  key_vault_id = azurerm_key_vault.wvd.id
}

## The domain join service account will be secured as a key vault secret
resource "azurerm_key_vault_secret" "wvd_domain_join_account" {
  name         = var.wvd_domain_join_username
  value        = var.wvd_domain_join_password
  key_vault_id = azurerm_key_vault.wvd.id
}

## The bastion host will secure RDP connections to all session hosts
resource "azurerm_bastion_host" "wvd_bastion" {
  name                = var.wvd_bastion_name
  location            = azurerm_resource_group.wvd.location
  resource_group_name = azurerm_resource_group.wvd.name

  ip_configuration {
    name                 = "ipc-azprd-frc-${var.wvd_bastion_name}"
    subnet_id            = azurerm_subnet.wvd_bastion.id
    public_ip_address_id = azurerm_public_ip.wvd_bastion.id
  }
}