resource "azurerm_kubernetes_cluster" "dors" {
    name                = var.dors_aks_cluster_name
    location            = azurerm_resource_group.dors_resource_group.location
    resource_group_name = azurerm_resource_group.dors_resource_group.name
    dns_prefix          = var.dors_aks_dns_prefix
    node_resource_group = var.dors_aks_nodes_resource_group_name

    linux_profile {
        admin_username = ""
        ssh_key {
            key_data = file(var.dors_ssh_public_key)
        }
    }

    network_profile {
        load_balancer_sku = "Standard"
        network_plugin = "azure"
    }

    service_principal {
        client_id     = var.service_principal_client_id
        client_secret = var.service_principal_secret
    }

    default_node_pool {
        enable_auto_scaling  = true
        availability_zones   = ["1","2","3"]
        min_count            = 3
        max_count            = 5
        type                 = "VirtualMachineScaleSets"
        name                 = "Development"
        node_count           = var.dors_aks_node_count
        vm_size              = var.dors_aks_node_size
        os_disk_size_gb      = 30
        vnet_subnet_id       = azurerm_subnet.dors_subnet.id
    }

    addon_profile {
        oms_agent {
                enabled                    = true
                log_analytics_workspace_id = azurerm_log_analytics_workspace.dors_log_analytics_workspace.id
            }
    }
}