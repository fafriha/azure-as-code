resource "azurerm_log_analytics_workspace" "monitor" {
    name                = "${var.log_analytics_workspace_name}-law"
    location            = "${data.azurerm_resource_group.core.location}"
    resource_group_name = "${data.azurerm_resource_group.core.name}"
    sku                 = "PerGB2018"
}

resource "azurerm_log_analytics_solution" "monitor" {
    solution_name         = "ContainerInsights"
    location              = "${data.azurerm_resource_group.core.location}"
    workspace_resource_id = "${azurerm_log_analytics_workspace.monitor.id}"
    resource_group_name   = "${data.azurerm_resource_group.core.name}"
    workspace_name        = "${azurerm_log_analytics_workspace.monitor.name}"

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}