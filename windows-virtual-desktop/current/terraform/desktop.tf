## Creating all host pools
resource "azurerm_virtual_desktop_host_pool" "wvd_hostpool" {
  for_each                         = var.wvd_hostpool
  name                             = each.value.name
  location                         = each.value.location
  resource_group_name              = azurerm_resource_group.wvd_resource_group.name
  validate_environment             = each.value.validate_environment
  type                             = each.value.type
  load_balancer_type               = each.value.load_balancer_type
  friendly_name                    = each.value.friendly_name
  description                      = each.value.description
  personal_desktop_assignment_type = each.value.personal_desktop_assignment_type
  maximum_sessions_allowed         = each.value.maximum_sessions_allowed

  registration_info {
    expiration_date = each.value.expiration_date
  }
}

## Creating all application groups
resource "azurerm_virtual_desktop_application_group" "wvd_application_group" {
  for_each            = var.wvd_application_group
  name                = each.value.name
  type                = each.value.type
  location            = each.value.location
  resource_group_name = azurerm_resource_group.wvd_resource_group.name
  host_pool_id        = azurerm_virtual_desktop_host_pool.wvd_hostpool[each.value.hostpool_name].id
  friendly_name       = each.value.friendly_name
  description         = each.value.description
}

## Creating all workspaces
resource "azurerm_virtual_desktop_workspace" "wvd_workspace" {
  for_each            = var.wvd_workspace
  name                = each.value.name
  location            = each.value.location
  resource_group_name = azurerm_resource_group.wvd_resource_group.name
  friendly_name       = each.value.friendly_name
  description         = each.value.description
}

## Including application groups to relevant workspaces
resource "azurerm_virtual_desktop_workspace_application_group_association" "none" {
  for_each             = { for wks in local.workspaces : wks.name => wks }
  workspace_id         = azurerm_virtual_desktop_workspace.wvd_workspace[each.key].id
  application_group_id = azurerm_virtual_desktop_application_group.wvd_application_group[each.value.application_group_name].id
}