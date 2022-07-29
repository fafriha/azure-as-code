################################################### Mandatory - Values must be provided ################################################

variable "hub_network_resources" {
  description = "Please provide the information of your existing hub network resources."
  default = {
    "resource_group_name"      = "friha-vnethub-francecentral"
    "virtual_wan_name"         = "friha-vwan-francecentral"
    "virtual_hub_name"         = "friha-hub-francecentral"
    "virtual_network_name"     = "friha-vwan-global"
    "default_route_table_name" = "rt-prd-frc-01"
    "dns_servers_ip"           = ["192.168.253.5", "192.168.253.6"]
  }
}

variable "hub_identity_resources" {
  description = "Please provide the required information about your exsiting identity resources."
  default = {
    core = {
      "resource_group_name" = "rg-adds-identity-001"
    },
    directory = {
      "type"                = "AD"
      "storage_sid"         = "S-1-5-21-41432690-3719764436-1984117282"
      "domain_name"         = "friha.fr"
      "domain_sid"          = "S-1-5-21-2712788594-670464638-2875766106"
      "domain_guid"         = "74d0072b-ebf4-4149-9dc7-5a1e23cfc559"
      "forest_name"         = "friha"
      "netbios_domain_name" = "friha"
      "ou_path"             = "OU=EMEA,DC=friha,DC=fr"
    },
    accounts = {
      "svc-domain-join" = ""
      "local-admin"     = ""
    }
  }
}

################################################# Default values can be used ###################################################

variable "avd_resource_groups" {
  description = "Please provide a name and a location for the resource groups that will contain all resources."
  type        = map(any)
  default = {
    network = {
      "resource_group_name" = "rg-avd-location-prefix-network"
      "location"            = "francecentral"
    }
    storage = {
      "resource_group_name" = "rg-avd-location-prefix-pool-compute"
      "location"            = "francecentral"
    }
    compute = {
      "resource_group_name" = "rg-avd-location-prefix-service-objects"
      "location"            = "francecentral"
    }
    management = {
      "resource_group_name" = "rg-avd-location-prefix-management"
      "location"            = "francecentral"
    }
    service-objects = {
      "resource_group_name" = "rg-avd-location-prefix-network"
      "location"            = "westeurope"
    }
  }
}


## Changer pour intégrer NetApp account
variable "avd_storage" {
  description = "Enter the name of the storage account that will host all user profiles."
  default = {
    "function_account_name" = "saprdfrcfunc01"
    "function_account_kind" = "StorageV2"
    "function_account_tier" = "Standard"

    "netapp_or_azure"       = "azure"
    "profiles_account_name" = "saprdavd01"
    "profiles_account_kind" = "FileStorage" //Only for Azure Files
    "profiles_account_tier" = "Premium"
    "profiles_pool_name"    = "spprdfrcavd01"
    "pool_size"             = 5
    "volume_or_share_quota" = 100
    "volume_path"           = "profiles"

    "replication_type" = "LRS"
    "enable_https"     = "true"

    "volume_protocol" = ["NFSv3"]
  }
}

variable "avd_monitoring" {
  description = "Please provide the required information for monitoring resources."
  type        = map(string)
  default = {
    "log_analytics_workspace_name" = "law-prd-frc-avd-01"
    "log_analytics_workspace_sku"  = "PerGB2018"
    "app_insights_name"            = "ai-prd-frc-avd-01"
    "app_insights_type"            = "web"
    "retention_in_days"            = 30
    "internet_query_enabled"       = "false"
    "internet_ingestion_enabled"   = "false"
    "daily_quota_gb"               = 1
  }
}

variable "avd_key_vault_name" {
  description = "Please provide a name for the key vault."
  default     = "kv-prd-frc-avd-01"
}

variable "avd_hostpools" {
  description = "Please provide the required information to create a hostpool."
  type        = map(any)
  default = {
    contractors = {
      "name"                            = "personal-location-prefix-001"
      "load_balancer_type"              = "DepthFirst"
      "hostpool_type"                   = "Personal"
      "assignment_type"                 = "Automatic"
      "maximum_sessions_allowed"        = 16
      "friendly_name"                   = "Canary"
      "description"                     = "Dedicated to canary deployments."
      "vm_count"                        = 1
      "vm_size"                         = "Standard_F4s_v2"
      "vm_prefix"                       = "vm-avd-abcd"
      "availability_set"                = "false"
      "validate_environment"            = "true"
      "start_vm_on_connect"             = "true"
      "msi_name"                        = "msi-can-frc-avd-01"
      "virtual_network_name"            = "vnet-avd-location-prefix-001"
      "subnet_name"                     = "snet-avd-location-prefix-001"
      "address_space"                   = "192.168.1.0/27"
      "address_prefix"                  = "192.168.1.0/27"
      "network_security_group_name"     = "nsg-avd-frc-abcd-001"
      "application_security_group_name" = "asg-avd-frc-abcd-001"
      "patch_mode"                      = "Manual"
      "auto_updates"                    = "false"
      "license_type"                    = "Windows_Client"
      "image_publisher"                 = "MicrosoftWindowsDesktop"
      "image_offer"                     = "windows11preview"
      "image_sku"                       = "win11-22h2-avd-m365"
    }
    developpers = {
      "name"                            = "personal-location-prefix-002"
      "load_balancer_type"              = "DepthFirst"
      "hostpool_type"                   = "Personal"
      "assignment_type"                 = "Automatic"
      "maximum_sessions_allowed"        = 16
      "friendly_name"                   = "Canary"
      "description"                     = "Dedicated to canary deployments."
      "vm_count"                        = 1
      "vm_size"                         = "Standard_F4s_v2"
      "vm_prefix"                       = "vm-avd-efgh"
      "availability_set"                = "false"
      "validate_environment"            = "true"
      "start_vm_on_connect"             = "true"
      "msi_name"                        = "msi-can-frc-avd-01"
      "virtual_network_name"            = "vnet-avd-location-prefix-002"
      "subnet_name"                     = "snet-avd-location-prefix-002"
      "address_space"                   = "192.168.2.0/27"
      "address_prefix"                  = "192.168.2.0/27"
      "network_security_group_name"     = "nsg-avd-frc-efgh-001"
      "application_security_group_name" = "asg-avd-frc-efgh-001"
      "patch_mode"                      = "Manual"
      "auto_updates"                    = "false"
      "license_type"                    = "Windows_Client"
      "image_publisher"                 = "MicrosoftWindowsDesktop"
      "image_offer"                     = "windows11preview"
      "image_sku"                       = "win11-22h2-avd-m365"
    }
    students = {
      "name"                            = "pool-location-prefix-001"
      "load_balancer_type"              = "DepthFirst"
      "hostpool_type"                   = "Pooled"
      "maximum_sessions_allowed"        = 16
      "friendly_name"                   = "Canary"
      "description"                     = "Dedicated to canary deployments."
      "vm_count"                        = 1
      "vm_size"                         = "Standard_F4s_v2"
      "vm_prefix"                       = "vm-avd-ijkl"
      "availability_set"                = "false"
      "validate_environment"            = "true"
      "start_vm_on_connect"             = "true"
      "msi_name"                        = "msi-can-frc-avd-01"
      "virtual_network_name"            = "vnet-avd-location-prefix-003"
      "subnet_name"                     = "snet-avd-location-prefix-003"
      "address_space"                   = "192.168.3.0/27"
      "address_prefix"                  = "192.168.3.0/27"
      "network_security_group_name"     = "nsg-avd-frc-ijkl-001"
      "application_security_group_name" = "asg-avd-frc-ijkl-001"
      "patch_mode"                      = "Manual"
      "auto_updates"                    = "false"
      "license_type"                    = "Windows_Client"
      "image_publisher"                 = "MicrosoftWindowsDesktop"
      "image_offer"                     = "windows11preview"
      "image_sku"                       = "win11-22h2-avd-m365"
    }
    hires = {
      "name"                            = "pool-location-prefix-002"
      "load_balancer_type"              = "DepthFirst"
      "hostpool_type"                   = "Pooled"
      "maximum_sessions_allowed"        = 16
      "friendly_name"                   = "Canary"
      "description"                     = "Dedicated to canary deployments."
      "vm_count"                        = 1
      "vm_size"                         = "Standard_F4s_v2"
      "vm_prefix"                       = "vm-avd-mnop"
      "availability_set"                = "false"
      "validate_environment"            = "true"
      "start_vm_on_connect"             = "true"
      "msi_name"                        = "msi-can-frc-avd-01"
      "virtual_network_name"            = "vnet-avd-location-prefix-004"
      "subnet_name"                     = "snet-avd-location-prefix-004"
      "address_space"                   = "192.168.4.0/27"
      "address_prefix"                  = "192.168.4.0/27"
      "network_security_group_name"     = "nsg-avd-frc-mnop-001"
      "application_security_group_name" = "asg-avd-frc-mnop-001"
      "patch_mode"                      = "Manual"
      "auto_updates"                    = "false"
      "license_type"                    = "Windows_Client"
      "image_publisher"                 = "MicrosoftWindowsDesktop"
      "image_offer"                     = "windows11preview"
      "image_sku"                       = "win11-22h2-avd-m365"
    }
  }
}

variable "avd_application_groups" {
  description = "Please provide the required information to create an application group."
  type        = map(any)
  default = {
    session = {
      "name"          = "ag-can-frc-avd-01"
      "type"          = "Desktop"
      "location"      = "francecentral"
      "friendly_name" = "Canary"
      "description"   = "Dedicated to canary deployments."
      "hostpool_name" = "personal-location-prefix-001"
      "users"         = ["john@friha.fr", "clark@friha.fr", "marika@friha.fr"]
    }
    internal = {
      "name"          = "ag-prd-frc-avd-01"
      "type"          = "Desktop"
      "location"      = "francecentral"
      "friendly_name" = "Canary"
      "description"   = "Dedicated to canary deployments."
      "hostpool_name" = "personal-location-prefix-002"
      "users"         = ["john@friha.fr", "clark@friha.fr", "marika@friha.fr"]
    }
    external = {
      "name"          = "ag-prd-frc-avd-02"
      "type"          = "Desktop"
      "location"      = "francecentral"
      "friendly_name" = "Canary"
      "description"   = "Dedicated to canary deployments."
      "hostpool_name" = "pool-location-prefix-001"
      "users"         = ["john@friha.fr", "clark@friha.fr", "marika@friha.fr"]
    }
    students = {
      "name"          = "ag-prd-frc-avd-03"
      "type"          = "Desktop"
      "location"      = "francecentral"
      "friendly_name" = "Office"
      "description"   = "Dedicated to medium workload type (Microsoft Word, CLIs, ...)."
      "hostpool_name" = "pool-location-prefix-002"
      "users"         = ["lisa@friha.fr", "yahya@friha.fr"]
    }
  }
}

variable "avd_workspaces" {
  description = "Please provide the required information to create a workspace."
  type        = map(any)
  default = {
    session = {
      "name"                   = "wks-can-frc-avd-01"
      "friendly_name"          = "Canary"
      "description"            = "Dedicated to canary deployments."
      "location"               = "francecentral"
      "application_group_name" = ["ag-can-frc-avd-01"]
    },
    finance = {
      "name"                   = "wks-prd-frc-avd-01"
      "friendly_name"          = "Standard"
      "location"               = "francecentral"
      "description"            = "Dedicated to medium workload type (Microsoft Word, CLIs, ...)."
      "application_group_name" = ["ag-prd-frc-avd-01"]
    }
  }
}

###################################################### DO NOT MODIFY ######################################################
################## Flatening inputs into collections where each element corresponds to a single resource ##################

locals {

  session_hosts = flatten([
    for hp in var.avd_hostpools : [
      for i in range(hp.vm_count) :
      {
        hostpool_name    = hp.name
        vm_size          = hp.vm_size
        vm_prefix        = hp.vm_prefix
        availability_set = hp.availability_set
        index            = i
      }
    ]
  ])

  application_groups = flatten([
    for ag in var.avd_application_groups : [
      for i in range(length(ag.users)) :
      {
        name = ag.name
        user = ag.users[i]
      }
    ]
  ])

  workspaces = flatten([
    for wks in var.avd_workspaces : [
      for i in range(length(wks.application_group_name)) :
      {
        name                   = wks.name
        application_group_name = wks.application_group_name[i]
      }
    ]
  ])
}