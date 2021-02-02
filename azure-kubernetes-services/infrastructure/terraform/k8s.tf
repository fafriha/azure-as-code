resource "azurerm_kubernetes_cluster" "dors" {
    name                = var.dors_aks["cluster_name"]
    location            = azurerm_resource_group.dors_resource_group.location
    resource_group_name = azurerm_resource_group.dors_resource_group.name
    node_resource_group = var.dors_aks_nodes_resource_group_name
    dns_prefix          = var.dors_aks["dns_prefix"]

    linux_profile {
        admin_username = var.dors_admin_account("username"])
        ssh_key {
            key_data = file(var.dors_admin_account["ssh_public_key"])
        }
    }

    network_profile {
        load_balancer_sku = var.dors_aks["load_balancer_sku"]
        network_plugin = var.dors_aks["network_plugin"]
    }

    identity {
        type = "SystemAssigned"
    }

    azure_active_directory {
        managed = true
    }

    role_based_access_control {
        enabled = true
    }

    default_node_pool {
        enable_auto_scaling  = var.dors_aks["enable_auto_scaling"]
        availability_zones   = var.dors_aks["availability_zones"]
        min_count            = var.dors_aks["default_nodes_min_count"]
        max_count            = var.dors_aks["default_nodes_max_count"]
        type                 = var.dors_aks["default_nodes_type"]
        name                 = var.dors_aks["default_node_pool_name"]
        node_count           = var.dors_aks["default_node_count"]
        vm_size              = var.dors_aks["default_node_size"]
        os_disk_size_gb      = var.dors_aks["default_node_os_disk_size_gb"]
        vnet_subnet_id       = azurerm_subnet.dors_subnet.id
    }

    addon_profile {
        oms_agent {
                enabled                    = true
                log_analytics_workspace_id = azurerm_log_analytics_workspace.dors_log_analytics_workspace.id
            }
    }
}