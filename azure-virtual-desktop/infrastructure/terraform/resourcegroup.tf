## Creating all resource groups to host all resources
resource "azurerm_resource_group" "avd_rgs" {
  for_each = var.avd_resource_groups
  name     = each.value.resource_group_name
  location = each.value.location
}