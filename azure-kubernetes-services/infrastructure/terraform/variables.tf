################################################### Mandatory - Values must be provided ################################################
variable "hub_resources" {
  description = "Please provide the information of your existing hub's resources and the desired name of the peering to the WVD's virtual network."
  default = {
    "resource_group_name"      = "rg-prd-frc-hub-01"
    "virtual_network_name"     = "vnet-prd-frc-hub-01"
    "peering_name"             = "peer-prd-frc-hub-to-dors-01"
    "default_route_table_name" = "rt-prd-frc-01"
  }
}

variable "dors_admin_account" {
  description = "Please provide the required information for the local administrator account."
  type        = map(string)
  default = {
    "username"       = ""
    "ssh_public_key" = ""
    "passwod"        = ""
  }
}

variable "terraform_sp" {
  description = "Please provide the required information about your existing Terraform Service Principal."
  type        = map(string)
  default = {
    "client_id"     = ""
    "client_secret" = ""
  }
}

variable "aad_tenant_id" {
  description = "Please provide the ID of your existing Azure AD tenant."
  default     = ""
}

variable "subscription_id" {
  description = "Please provide the ID of your existing subscription."
  default     = ""
}

################################################# Optional - Default values can be used ###################################################
variable "dors_resource_group" {
  description = "Please provide a name and a location for the resource group that will contain all WVD resources."
  type        = map(string)
  default = {
    "app"       = "rg-prd-frc-dors-app-01"
    "nodes"     = "rg-prd-frc-dors-nodes-01"
    "location"  = "francecentral"
  }
}

variable "dors_aks" {
  description = "Please provide the required information to create a WVD hostpool."
  type        = map(any)
  default = {
      "cluster_name"                = "aks-prd-frc-dors-01"
      "dns_prefix"                  = "dors"
      "load_balancer_sku"           = "standard"
      "network_plugin"              = "azure"
      "enable_auto_scaling"         = true
      "availability_zones"          = ["1","2","3"]
      "default_nodes_min_count"     = 3
      "default_nodes_max_count"     = 5
      "default_nodes_type"          = "VirtualMachineScaleSets"
      "default_node_pool_name"      = "Canary"
      "default_node_count"          = 3
      "default_node_size"           = "Standard_D4s_v2"
      "default_node_os_disk_size"   = 30    
    }
}

variable "dors_virtual_network" {
  description = "Please provide the required networking information for the environment."
  type        = map(string)
  default = {
    "virtual_network_name"        = "vnet-prd-frc-dors-01"
    "address_space"               = "192.168.2.0/24"
    "peering_name"                = "peer-prd-frc-dors-to-core-01"
    "network_security_group_name" = "nsg-prd-frc-dors-01"
  }
}

variable "dors_subnets" {
  description = "Please provide the required networking information for the environment."
  type        = map(any)
  default = {
    "subnet_name"    = "snet-can-frc-dors-01"
    "address_prefix" = "192.168.2.192/27"
  }
}

variable "dors_storage" {
  description = "[Mandatory] [Create] Enter the name of the storage account that will host all user profiles."
  default = {   
    "account_name"          = "saprdfrcdors01"
    "account_kind"          = "FileStorage"
    "account_tier"          = "Premium"
    "share_name"            = "dors"
    "share_quota"           = 10
    "replication_type"      = "LRS"
    "enable_https"          = true
  }
}

variable "dors_database" {
  description = "[Mandatory] [Create] Enter the name of the storage account that will host all user profiles."
  default = {   
    "mysql_server_name"                 = "mysqlsrv-prd-frc-dors-01"
    "mysql_database_name"               = "mysqldb-prd-frc-dors-01"
    "sku_name"                          = "GP_Gen5_2"
    "storage_mb"                        = 5120
    "version"                           = "5.7"
    "auto_grow_enabled"                 = true
    "backup_retention_days"             = 7
    "geo_redundant_backup_enabled"      = true
    "infrastructure_encryption_enabled" = true
    "public_network_access_enabled"     = false
    "ssl_enforcement_enabled"           = true
    "ssl_minimal_tls_version_enforced"  = "TLS1_2"
    "charset"                           = "utf8"
    "collation"                         = "utf8_unicode_ci"
    }
}


variable "dors_monitoring" {
  description = "Please provide the required information about for monitoring resources."
  type        = map(string)
  default = {
    "log_analytics_workspace_name" = "law-prd-frc-dors-01"
    "log_analytics_workspace_sku"  = "PerGB2018"
    "retention_in_days"            = 30
  }
}

variable "dors_acr" {
  description = "Please provide the required information about for monitoring resources."
  type        = map(string)
  default = {
    "registry_name"     = "acr-prd-frc-dors-01"
    "sku"               = "Basic"
    "admin_enabled"     = false
  }
}