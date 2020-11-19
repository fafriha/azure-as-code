## Getting the currently used service principal configuration
data "azurerm_client_config" "current" {}

## Gathering application groups members details
#### WARNING - Adding users to application groups required User Access Administrator or Owner rights
# data "azuread_user" "wvd_users" {
#   for_each            = toset([for u in local.application_groups : u.user])
#   user_principal_name = each.key
# }

## Gathering hub resource group details
data "azurerm_resource_group" "hub_resource_group" {
  name = var.hub_resources["resource_group_name"]
}

## Gathering hub virtual network details
data "azurerm_virtual_network" "hub_virtual_network" {
  name                = var.hub_resources["virtual_network_name"]
  resource_group_name = var.hub_resources["resource_group_name"]
}

# ## Gathering hub route table details
# #### Enable this block if you have a route table routing all traffic to a hub firewall
# data "azurerm_route_table" "hub_rt" {
#   name                = var.hub_resources["default_route_table_name"]
#   resource_group_name = var.hub_resources["resource_group_name"]
# }

# ## Gathering managed image details
# #### Enable this if you are using a managed image to create session hosts
# data "azurerm_image" "wvd" {
#   name                    = "windows10-img"
#   resource_group_name     = azurerm_resource_group.wvd.name
# }

data "template_file" "wvd_deploy_agents" {
  for_each             = azurerm_windows_virtual_machine.wvd_hosts
  template = file("../powershell/script/Install-Agents.ps1")

  vars = {
      RegistrationToken = "${azurerm_virtual_desktop_host_pool.wvd_hostpool[each.value.tags.hostpool].registration_info[0].token}"
      LocalAdminName = "${var.wvd_local_admin_account["username"]}"
      FileShare = "${replace(replace(azurerm_storage_share.wvd_profiles["${each.value.tags.hostpool}-profiles"].url, "https:", ""), "/", "\\")}"
  }
}