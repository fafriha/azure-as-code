## Creating all host pools
resource "azurerm_virtual_desktop_host_pool" "avd_hostpools" {
  for_each                         = { for hp in var.avd_hostpools : hp.name => hp }
  name                             = each.key
  location                         = azurerm_resource_group.avd_rgs["service-objects"].location
  resource_group_name              = azurerm_resource_group.avd_rgs["service-objects"].name
  validate_environment             = each.value.validate_environment
  start_vm_on_connect              = each.value.start_vm_on_connect
  type                             = each.value.hostpool_type
  load_balancer_type               = each.value.load_balancer_type
  friendly_name                    = each.value.friendly_name
  description                      = each.value.description
  personal_desktop_assignment_type = each.value.hostpool_type != "Pooled" ? each.value.assignment_type : null
  maximum_sessions_allowed         = each.value.maximum_sessions_allowed
}

## Creating all application groups
resource "azurerm_virtual_desktop_application_group" "avd_application_groups" {
  for_each            = { for ag in var.avd_application_groups : ag.name => ag }
  name                = each.key
  type                = each.value.type
  location            = azurerm_resource_group.avd_rgs["service-objects"].location
  resource_group_name = azurerm_resource_group.avd_rgs["service-objects"].name
  host_pool_id        = azurerm_virtual_desktop_host_pool.avd_hostpools[each.value.hostpool_name].id
  friendly_name       = each.value.friendly_name
  description         = each.value.description
}

## Creating all workspaces
resource "azurerm_virtual_desktop_workspace" "avd_workspaces" {
  for_each            = { for wks in var.avd_workspaces : wks.name => wks }
  name                = each.key
  location            = azurerm_resource_group.avd_rgs["service-objects"].location
  resource_group_name = azurerm_resource_group.avd_rgs["service-objects"].name
  friendly_name       = each.value.friendly_name
  description         = each.value.description
}

## Including application groups to relevant workspaces
resource "azurerm_virtual_desktop_workspace_application_group_association" "none" {
  for_each             = { for wks in local.workspaces : wks.name => wks }
  workspace_id         = azurerm_virtual_desktop_workspace.avd_workspaces[each.key].id
  application_group_id = azurerm_virtual_desktop_application_group.avd_application_groups[each.value.application_group_name].id
}

## Generating host pools registration key
resource "azurerm_virtual_desktop_host_pool_registration_info" "avd_registration_info" {
  for_each        = { for hp in var.avd_hostpools : hp.name => hp }
  hostpool_id     = azurerm_virtual_desktop_host_pool.avd_hostpools[each.key].id
  expiration_date = timeadd(timestamp(), "15m")
}