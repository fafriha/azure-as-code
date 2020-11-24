################################################### Mandatory ################################################

variable "hub_resources" {
  description = "Please provide the information of your existing hub's resources and the desired name of the peering to the WVD's virtual network."
  default = {
    "resource_group_name"      = "rg-prd-frc-hub-01"
    "virtual_network_name"     = "vnet-prd-frc-hub-01"
    "peering_name"             = "peer-prd-frc-hub-to-wvd-01"
    "default_route_table_name" = "rt-prd-frc-hub-01"
  }
}

variable "wvd_resource_group" {
  description = "Please provide a name and a location for the resource group that will contain all WVD related resources."
  type        = map(string)
  default = {
    "resource_group_name" = "rg-prd-frc-wvd-01"
    "location"            = "francecentral"
  }
}

variable "wvd_hostpool" {
  description = "Please provide the required information to create a WVD hostpool."
  type        = map(any)
  default = {
    hp-can-frc-wvd-01 = {
      "name"                             = "hp-can-frc-wvd-01"
      "type"                             = "Pooled"
      "load_balancer_type"               = "DepthFirst"
      "personal_desktop_assignment_type" = "Automatic"
      "maximum_sessions_allowed"         = 16
      "expiration_date"                  = "2020-12-10T18:46:43Z"
      "friendly_name"                    = "Canary"
      "description"                      = "Dedicated to canary deployments."
      "location"                         = "EastUs"
      "vm_count"                         = 1
      "vm_size"                          = "Standard_F4s_v2"
      "vm_prefix"                        = "host-can-frc"
      "validate_environment"             = "true"
    },
    hp-prd-frc-wvd-02 = {
      "name"                             = "hp-prd-frc-wvd-02"
      "type"                             = "Personal"
      "load_balancer_type"               = "Persistent"
      "personal_desktop_assignment_type" = "Automatic"
      "maximum_sessions_allowed"         = 16
      "expiration_date"                  = "2020-12-10T18:46:43Z"
      "friendly_name"                    = "Office"
      "description"                      = "Dedicated to medium workload type (Microsoft Word, CLIs, ...)."
      "location"                         = "EastUs"
      "vm_count"                         = 1
      "vm_size"                          = "Standard_F4s_v2"
      "vm_prefix"                        = "host-prd-frc"
      "validate_environment"             = "false"
    }
  }
}

######################################################### WARNING #######################################################
## Adding users to application groups requires User Access Administrator or Owner rights and Reader rights on Azure AD ##
#########################################################################################################################
variable "wvd_application_group" {
  description = "Please provide the required information to create a WVD application group."
  type        = map(any)
  default = {
    ag-can-frc-wvd-01 = {
      "name"           = "ag-can-frc-wvd-01"
      "type"           = "Desktop"
      "location"       = "EastUs"
      "friendly_name"  = "Canary"
      "description"    = "Dedicated to canary deployments."
      "hostpool_name"  = "hp-can-frc-wvd-01"
      "users"          = ["john@friha.fr", "clark@friha.fr", "marika@friha.fr"] 
    },
    ag-prd-frc-wvd-02 = {
      "name"           = "ag-prd-frc-wvd-02"
      "type"           = "Desktop"
      "location"       = "EastUs"
      "friendly_name"  = "Office"
      "description"    = "Dedicated to medium workload type (Microsoft Word, CLIs, ...)."
      "hostpool_name"  = "hp-prd-frc-wvd-02"
      "users"          = ["lisa@friha.fr", "yahya@friha.fr"]
    }
  }
}

variable "wvd_workspace" {
  description = "Please provide the required information to create a WVD workspace."
  type        = map(any)
  default = {
    wks-can-frc-wvd-01 = {
      "name"                   = "wks-can-frc-wvd-01"
      "friendly_name"          = "Canary"
      "description"            = "Dedicated to canary deployments."
      "location"               = "EastUs"
      "application_group_name" = ["ag-can-frc-wvd-01"]
    },
    wks-prd-frc-wvd-02 = {
      "name"                   = "wks-prd-frc-wvd-02"
      "friendly_name"          = "Standard"
      "location"               = "EastUs"
      "description"            = "Dedicated to medium workload type (Microsoft Word, CLIs, ...)."
      "application_group_name" = ["ag-prd-frc-wvd-02"]
    }
  }
}

variable "wvd_virtual_network" {
  description = "Please provide the required networking information for the environment."
  type        = map(string)
  default = {
    "virtual_network_name"          = "vnet-prd-frc-wvd-01"
    "address_space"                 = "192.168.1.0/24"
    "peering_name"                  = "peer-prd-frc-wvd-to-core-01"
    "network_security_group_name"   = "nsg-prd-frc-wvd-01"
  }
}

variable "wvd_subnet" {
  description = "Please provide the required networking information for the environment."
  type        = map(any)
  default = {
    snet-can-frc-wvd-01 = {
      "subnet_name"    = "snet-can-frc-wvd-01"
      "address_prefix" = "192.168.1.192/27"
    },
    snet-prd-frc-wvd-01 = {
      "subnet_name"     = "snet-prd-frc-wvd-01"
      "address_prefix"  = "192.168.1.0/27"
    }
  }
}

variable "wvd_storage" {
  description = "[Mandatory] [Create] Enter the name of the storage account that will host all user profiles."
  type        = map(string)
  default = {
    "function_account_name" = "saprdfrcwvd01"
    "function_account_kind" = "StorageV2"
    "function_account_tier" = "Standard"
    "profiles_account_name" = "saprdfrcwvd02"
    "profiles_account_kind" = "FileStorage"
    "profiles_account_tier" = "Premium"
    "replication_type"      = "LRS"
    "enable_https"          = "true"
  }
}

variable "wvd_monitoring" {
  description = "Please provide the required information about for monitoring resources."
  type        = map(string)
  default = {
    "log_analytics_workspace_name" = "law-prd-frc-wvd-01"
    "app_insights_name"            = "ai-prd-frc-wvd-01"
    "app_insights_type"            = "web"
  }
}

variable "wvd_events" {
  description = "Please provide the required informations for the pusblished events."
  type        = map(string)
  default = {
    "topic_name"        = "topic-prd-frc-wvd-01"
    "topic_type"        = "Microsoft.KeyVault.vaults"
    "subscription_name" = "sub-prd-frc-wvd-01"
    "event_handler"     = "fa-prd-frc-wvd-01"
  }
}

variable "wvd_app_service_plan" {
  description = "Please provide the required information about the app service plan that will host the function."
  type        = map(string)
  default = {
    "name" = "asp-prd-frc-wvd-01"
    "kind" = "FunctionApp"
    "tier" = "Dynamic"
    "size" = "Y1"
  }
}

variable "wvd_function" {
  description = "Please provide the required information for the functions"
  type        = map(any)
  default = {
    fa-prd-frc-wvd-01 = {
      "name"             = "fa-prd-frc-wvd-01"
      "runtime"          = "powershell"
      "version"          = "~3"
      "https_only"       = "true"
      "disable_homepage" = "true"
      "secrets_storage"  = "keyvault"
      "package_uri"      = "https://github.com/faroukfriha/azure-as-code/raw/master/windows-virtual-desktop/current/powershell/function/Renew-RegistrationTokenAfterExpiration.zip"
    }
  }
}

variable "wvd_key_vault_name" {
  description = "Please provide a name for the key vault."
  default     = "kv-prd-frc-wvd-01"
}

variable "wvd_sp_roles" {
  description = "Please provide the required informations about the Managed Identity of the Function App and the Terraform Service Principal."
  type        = map(any)
  default = {
    fa-prd-frc-wvd-01 = {
      "name"  = "fa-prd-frc-wvd-01"
      "roles" = ["Contributor", "Key Vault Secrets Officer (preview)"]
    },
    tf = {
      "name"  = "Terraform Service Principal"
      "roles" = ["Key Vault Secrets Officer (preview)"]
    }
  }
}

variable "wvd_domain" {
  description = "Please provide the required information about your exsiting Active Directory domain."
  type        = map(string)
  default = {
    "domain_name" = "friha.fr"
    "ou_path"     = "OU=EMEA,DC=friha,DC=fr"
  }
}

variable "wvd_domain_join_account" {
  description = "Please provide the required information about your existing domain join service account."
  type        = map(string)
  default = {
    "username" = ""
    "password" = ""
  }
}

variable "wvd_local_admin_account" {
  description = "Please provide the required information for the local administrator account."
  type        = map(string)
  default = {
    "username" = ""
    "password" = ""
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

################################################### Locals ################################################
## Flatening inputs into collections where each element corresponds to a single resource
locals {

  sp_roles = flatten([
    for sp in var.wvd_sp_roles : [
      for r in range(length(sp.roles)) :
      {
        name = sp.name
        role = sp.roles[r]
      }
    ]
  ])

  session_hosts = flatten([
    for hp in var.wvd_hostpool : [
      for i in range(hp.vm_count) :
      {
        vm_size       = hp.vm_size
        vm_prefix     = hp.vm_prefix
        hostpool_name = hp.name
        index         = i
      }
    ]
  ])

  application_groups = flatten([
    for ag in var.wvd_application_group : [
      for i in range(length(ag.users)) :
      {
        name = ag.name
        user = ag.users[i]
      }
    ]
  ])

  workspaces = flatten([
    for wks in var.wvd_workspace : [
      for i in range(length(wks.application_group_name)) :
      {
        name                   = wks.name
        application_group_name = wks.application_group_name[i]
      }
    ]
  ])
}