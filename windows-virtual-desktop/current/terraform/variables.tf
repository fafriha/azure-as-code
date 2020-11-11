variable "tf_backend" {
  description = "[Mandatory] [Import] Enter the name of your hub virtual network to which your domain controllers are connected to"
  type        = map(string)
  default = {
    "resource_group_name"  = "rg-prd-frc-tf-01"
    "storage_account_name" = "saprdfrctf01"
    "container_name"       = "windows-virtual-desktop"
    "blob_name"            = "prd-terraform.tfstate"
  }
}

variable "hub_resource_group_name" {
  description = "[Mandatory] [Import] Enter the name of your existing hub resource group which contains or allows you to communicate with your core resources (domain controllers, dns servers, firewall, ...)"
  default     = "rg-prd-frc-hub-01"
}

variable "tf_backend" {
  description = "[Mandatory] [Import] Enter the name of your hub virtual network to which your domain controllers are connected to"
  type        = map(string)
  default = {
    "resource_group_name"  = "rg-prd-frc-tf-01"
    "storage_account_name" = "saprdfrctf01"
    "container_name"       = "windows-virtual-desktop"
    "blob_name"            = "prd-terraform.tfstate"
  }
}

variable "hub_virtual_network" {
  description = "[Mandatory] [Import] Enter the name of your hub virtual network to which your domain controllers are connected to"
  type        = map(string)
  default = {
    "name"         = "vnet-prd-frc-hub-01"
    "peering_name" = "peer-prd-frc-hub-to-wvd-01"
  }
}

################################################### Windows Virtual Desktop ################################################

variable "wvd_resource_group" {
  description = "[Mandatory] [Create] Provide the required information to create the resource group in which all Windows Virtual Desktop resources will de deployed."
  type        = map(string)
  default = {
    "name"     = "rg-prd-frc-wvd-01"
    "location" = "francecentral"
  }
}

variable "wvd_host_pools" {
  description = "[Mandatory] [Import] Provide the required information about the host pool you wan to create."
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
      "vm_count"                         = 2
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
      "vm_count"                         = 2
      "vm_size"                          = "Standard_F4s_v2"
      "vm_prefix"                        = "host-prd-frc"
      "validate_environment"             = "false"
    }
  }
}

variable "wvd_application_groups" {
  description = "[Mandatory] [Import] Enter the required informations to create the application group."
  type        = map(any)
  default = {
    ag-can-frc-wvd-01 = {
      "name"           = "ag-can-frc-wvd-01"
      "type"           = "Desktop"
      "location"       = "EastUs"
      "friendly_name"  = "Canary"
      "description"    = "Dedicated to canary deployments."
      "host_pool_name" = "hp-can-frc-wvd-01"
      "users"          = ["user@company.com"]
    },
    ag-prd-frc-wvd-02 = {
      "name"           = "ag-prd-frc-wvd-02"
      "type"           = "Desktop"
      "location"       = "EastUs"
      "friendly_name"  = "Office"
      "description"    = "Dedicated to medium workload type (Microsoft Word, CLIs, ...)."
      "host_pool_name" = "hp-prd-frc-wvd-02"
      "users"          = ["user@company.com"]
    }
  }
}

variable "wvd_workspaces" {
  description = "[Mandatory] [Create] Enter the information related to the workspace that will contain application groups."
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
  description = "[Mandatory] [Create] Enter the name of the virtual network that will host all session hosts."
  type        = map(any)
  default = {
    "name"                          = "vnet-prd-frc-wvd-01"
    "address_space"                 = "192.168.1.0/24"
    "peering_name"                  = "peer-prd-frc-wvd-to-core-01"
    "bastion_subnet_name"           = "AzureBastionSubnet"
    "bastion_subnet_address_prefix" = "192.168.1.224/27"
    "canary_subnet_name"            = "snet-can-frc-wvd-01"
    "canary_subnet_address_prefix"  = "192.168.1.192/27"
    "clients_subnet_name"           = "snet-prd-frc-wvd-01"
    "clients_subnet_address_prefix" = "192.168.1.0/27"
    "default_route_table_name"      = "rt-prd-frc-default-01"
  }
}

variable "wvd_network_security_group_name" {
  description = "[Mandatory] [Create] Enter the name of the network security group that will secure the incoming and outgoing hosts internal traffic."
  default     = "nsg-prd-frc-wvd-01"
}

variable "wvd_log_analytics_workspace_name" {
  description = "[Mandatory] [Create] Enter the name of the log analytics workspace that will be part of the monitoring solution."
  default     = "log-prd-frc-wvd-01"
}

variable "wvd_public_ip_name" {
  description = "[Mandatory] [Create] Enter the name of the public IP address that will be assigned to the bastion host."
  default     = "pip-prd-frc-wvd-01"
}

variable "wvd_bastion_name" {
  description = "[Mandatory] [Create] Enter the name of the bastion host that will allow you to connect securely to all session hosts."
  default     = "bas-prd-frc-wvd-01"
}

variable "wvd_storage_accounts" {
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

variable "wvd_key_vault_name" {
  description = "[Mandatory] [Create] Enter the name of the key vault that will store all passwords and secrets securely."
  default     = "kv-prd-frc-wvd-01"
}

variable "wvd_domain" {
  description = "[Mandatory] [Import] Enter the name of your domain to join the sesion hosts to."
  type        = map(string)
  default = {
    "name"    = "friha.fr"
    "ou_path" = "OU=EMEA,DC=friha,DC=fr"
  }
}

variable "wvd_domain_join_account" {
  description = "[Mandatory] [Import] Provide the required information about the service account used to join machines to the domain."
  type        = map(string)
  default = {
    "username" = ""
    "password" = ""
  }
}

variable "wvd_local_admin_account" {
  description = "[Mandatory] [Import] Provide the required information about the account that wil be the local administrator of all session hosts."
  type        = map(string)
  default = {
    "username" = ""
    "password" = ""
  }
}

variable "wvd_app_service_plan" {
  description = "[Mandatory] "
  type        = map(string)
  default = {
    "name" = "asp-prd-frc-wvd-01"
    "kind" = "FunctionApp"
    "tier" = "Dynamic"
    "size" = "Y1"
  }
}

variable "wvd_app_insights" {
  description = "[Mandatory] "
  type        = map(string)
  default = {
    "name" = "ai-prd-frc-wvd-01"
    "type" = "web"
  }
}

variable "wvd_events" {
  description = "[Mandatory] [Import] "
  type        = map(string)
  default = {
    "topic_name"        = "topic-prd-frc-wvd-01"
    "topic_type"        = "Microsoft.KeyVault.vaults"
    "subscription_name" = "sub-prd-frc-wvd-01"
    "event_handler"     = "fa-prd-frc-wvd-01"
  }
}

variable "wvd_functions" {
  description = "[Mandatory] [Import] "
  type        = map(any)
  default = {
    fa-prd-frc-wvd-01 = {
      "name"             = "fa-prd-frc-wvd-01"
      "runtime"          = "powershell"
      "version"          = "~3"
      "https_only"       = "true"
      "disable_homepage" = "true"
      "secrets_storage"  = "keyvault"
      "package_uri"      = "https://github.com/faroukfriha/azure-as-code/raw/master/windows-virtual-desktop/current/powershell/functions/Renew-RegistrationTokenAfterExpiration.zip"
    }
  }
}

variable "wvd_sp_roles" {
  description = "[Mandatory] [Import] "
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

################################################### Locals ################################################
## Flatening inputs into a collection where each element corresponds to a single resource
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
    for hp in var.wvd_host_pools : [
      for i in range(hp.vm_count) :
      {
        vm_size        = hp.vm_size
        vm_prefix      = hp.vm_prefix
        host_pool_name = hp.name
        index          = i
      }
    ]
  ])

  application_groups = flatten([
    for ag in var.wvd_application_groups : [
      for i in range(length(ag.users)) :
      {
        name = ag.name
        user = ag.users[i]
      }
    ]
  ])

  workspaces = flatten([
    for wks in var.wvd_workspaces : [
      for i in range(length(wks.application_group_name)) :
      {
        name                   = wks.name
        application_group_name = wks.application_group_name[i]
      }
    ]
  ])
}

################################################### Global ################################################

variable "terraform_sp" {
  description = "[Mandatory] [Import] Enter the application (client) ID of the Terraform app you created."
  type        = map(string)
  default = {
    "client_id"     = ""
    "client_secret" = ""
  }
}

variable "aad_tenant_id" {
  description = "[Mandatory] [Import] Enter the ID of your Azure Active Directory tenant."
  default     = ""
}

variable "subscription_id" {
  description = "[Mandatory] [Import] Enter the Id of your subscription in which you want to deploy all resources."
  default     = ""
}