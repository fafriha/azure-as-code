resource "azurerm_log_analytics_workspace" "dors" {
    name                = var.log_analytics_workspace_name
    location            = azurerm_resource_group.dors_resource_group.location
    resource_group_name = azurerm_resource_group.dors_resource_group.name
    sku                 = "PerGB2018"
}

resource "azurerm_log_analytics_solution" "dors" {
    solution_name         = "ContainerInsights"
    location              = azurerm_resource_group.dors_resource_group.location
    workspace_resource_id = azurerm_log_analytics_workspace.dors.id
    resource_group_name   = azurerm_resource_group.dors_resource_group.name
    workspace_name        = azurerm_log_analytics_workspace.dors.name

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}