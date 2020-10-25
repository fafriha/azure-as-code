################################################### Production & Canary ################################################
## The virtual machines will be used as Windows Virtual Desktop session hosts
resource "azurerm_virtual_desktop_host_pool" "wvd" {
  for_each                         = var.wvd_host_pools
  name                             = each.value.name
  location                         = each.value.location
  resource_group_name              = azurerm_resource_group.wvd.name
  #validation_environment           = each.value.validation_environment
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

resource "azurerm_virtual_desktop_application_group" "wvd" {
  for_each            = var.wvd_application_groups
  name                = each.value.name
  type                = each.value.type
  location            = each.value.location
  resource_group_name = azurerm_resource_group.wvd.name
  host_pool_id        = azurerm_virtual_desktop_host_pool.wvd[each.value.host_pool_name].id
  friendly_name       = each.value.friendly_name
  description         = each.value.description
}

resource "azurerm_virtual_desktop_workspace" "wvd" {
  for_each            = var.wvd_workspaces
  name                = each.value.name
  location            = each.value.location
  resource_group_name = azurerm_resource_group.wvd.name
  friendly_name       = each.value.friendly_name
  description         = each.value.description
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "wvd" {
  for_each             = {for wks in local.workspaces : wks.name => wks}
  workspace_id         = azurerm_virtual_desktop_workspace.wvd[each.key].id
  application_group_id = azurerm_virtual_desktop_application_group.wvd[each.value.application_group_name].id
}