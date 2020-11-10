resource "azurerm_kubernetes_cluster" "core" {
    name                = "${var.cluster_name}"
    location            = "${data.azurerm_resource_group.core.location}"
    resource_group_name = "${data.azurerm_resource_group.core.name}"
    dns_prefix          = "${var.dns_prefix}"
    node_resource_group = "${var.node_resource_group_name}"

    linux_profile {
        admin_username = ""
        ssh_key {
            key_data = "${file("${var.ssh_public_key}")}"
        }
    }

    network_profile {
        load_balancer_sku = "Standard"
        network_plugin = "azure"
    }

    service_principal {
        client_id     = "${var.service_principal_client_id}"
        client_secret = "${var.service_principal_secret}"
    }

    default_node_pool {
        enable_auto_scaling  = true
        availability_zones   = ["1","2","3"]
        min_count            = 3
        max_count            = 5
        type                 = "VirtualMachineScaleSets"
        name                 = "corepool"
        node_count           = "${var.agent_count}"
        vm_size              = "Standard_DS1_v2"
        os_disk_size_gb      = 30
        vnet_subnet_id       = "${data.azurerm_subnet.core.id}"
    }

    addon_profile {
        oms_agent {
            enabled                    = true
            log_analytics_workspace_id = "${azurerm_log_analytics_workspace.monitor.id}"
            }
    }
}