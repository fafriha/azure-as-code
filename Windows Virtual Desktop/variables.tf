################################################### Hub ################################################

################################################### Windows virtual Desktop ################################################

variable "hub_resource_group_name" {
  #description = "Name of the resource group in which to deploy all ore resources"
  default     = "rg-azprd-frc-network-core-01"
}

variable "hub_default_route_table_name" {
  default = "rt-azprd-frc-default-01"
}

variable "img_resource_group_name" {
  description = "Name of the resource group that will contain all golden images"
  default     = "rg-azprd-frc-vm-img-wvd-01"
}

variable "wvd_resource_group_name" {
  description = "Name of the resource group in which to deploy the Windows Virtual Desktop infrastructure"
  default     = "rg-azprd-frc-wvd-01"
}


variable "hub_virtual_network_name" {
  default     = "vnet-azprd-frc-core-01"
  
}

variable "wvd_location" {
  description = "Location"
  default     = "francecentral"
}

variable "wvd_template_name" {
  description = "Template name"
  default     = "template-azprd-frc-wvd-01"
}

variable "wvd_network_security_group_name" {
  description = "NSG"
  default     = "nsg-azprd-frc-wvd-01"
}

variable "wvd_automation_account_name" {
  description = "Automation account name"
  default     = "aa-azprd-frc-wvd-01"
}

variable "wvd_runbook_name" {
  description = "Automation account name"
  default     = "runbook-azprd-frc-wvd-01"
}

variable "wvd_webhook_name" {
  description = "Automation account name"
  default     = "webhook-runbook-azprd-frc-wvd-01"
}

variable "wvd_connection_asset_name" {
  #description = "Automation account name"
  default     = "AzureRunAsConnection"
}

variable "wvd_time_before_logoff" {
  #description = "Automation account name"
  default     = "600"
}

variable "wvd_logoff_message_body" {
  #description = "Automation account name"
  default     = "Your session will end in 10 minutes. Please save your work now."
}

variable "wvd_logoff_message_title" {
  #description = "Automation account name"
  default     = "Log off session"
}

variable "wvd_maintenance_tag_name" {
  #description = "Automation account name"
  default     = "Production"
}

variable "wvd_minimum_session_host" {
  #description = "Automation account name"
  default     = "2"
}

variable "wvd_time_difference" {
  #description = "Automation account name"
  default     = "+1:00"
}

variable "wvd_max_session_per_cpu" {
  #description = "Automation account name"
  default     = "4"
}

variable "wvd_begin_peak_time" {
  #description = "Automation account name"
  default     = "9:00"
}

variable "wvd_end_peak_time" {
  #description = "Automation account name"
  default     = "18:00"
}

variable "wvd_logic_app_workflow_name" {
  #description = "Logic app workflow name"
  default     = "logic-azprd-frc-wvd-01"
}

variable "wvd_logic_app_trigger_frequency" {
  #description = "Logic app trigger frequency"
  default     = "Minute"
}

variable "wvd_logic_app_trigger_interval" {
  #description = "Logic app trigger interval"
  default     = "15"
}

variable "wvd_logic_app_action_name" {
  #description = "Logic app workflow name"
  default     = "HTTP Webhook"
}

variable "wvd_log_analytics_workspace_name" {
  #description = "Log analytics workspace name"
  default     = "log-azprd-frc-wvd-01"
}

variable "wvd_virtual_network_name" {
  description = "Name of the virtual network that will host all session hosts"
  default     = "vnet-azprd-frc-wvd-01"
}

variable "wvd_virtual_network_address_space" {
  description = "Adress space of the virtual network name"
  default     = "10.99.24.0/22"
}

variable "wvd_dns_servers" {
  description = "DNS servers"
  default     = "172.18.1.111"
}

variable "wvd_clients_subnet_name" {
  description = "A subnet to host all Windows client session hosts"
  default     = "sub-azprd-frc-wvd-01"
}

variable "wvd_clients_subnet_address_prefix" {
  description = "Address prefix"
  default     = "10.99.24.0/23"
}

variable "wvd_storage_account_name" {
  description = "Name of the storage that will host FSLogix containers"
  default     = "safrcsbxwvdfslogix1"
}

variable "wvd_file_share_name" {
  description = "Name of the FSLogix file share"
  default     = "profiles01"
}

variable "wvd_rdsh_count" {
  description = "Number of Windows Virtual Desktop session hosts to deploy"
  default     = 3
}

variable "wvd_host_pool_name" {
  #description = "Name of the existing Windows Virtual Desktop host pool"
  default     = "azprdwvdhp01"
}

variable "wvd_vm_prefix" {
  #description = "Prefix of the name of the Windows Virtual Desktop sessions hosts"
  default     = "azprdwvdh"
}

variable "wvd_tenant_name" {
  description = "Name of the existing Windows Virtual Desktop tenant associated with the session hosts"
  default     = "PVCP"
}

variable "wvd_local_admin_name" {
  description = "Name of the local admin account"
  default     = "adminpvcp"
}

variable "wvd_local_admin_value" {
  description = "Password of the local admin account"
  default = "P@ssword1234567890"
}

variable "wvd_registration_expiration_hours" {
  description = "The expiration time for registration in hours"
  default     = "48"
}

variable "wvd_key_vault_name" {
  description = "Name of the existing key vault in which credentials are stored"
  default     = "kv-azprd-frc-wvd-01"
}

variable "wvd_domain_joined" {
  description = "Should the machine join a domain"
  default     = "true"
}

variable "wvd_domain_name" {
  description = "Name of the existing domain to join"
  default     = "pvcp.intra"
}

variable "wvd_domain_join_name" {
  description = "Name of the existing user to authenticate with the domain"
  default     = "svc-addswvd"
}

variable "wvd_domain_join_value" {
  description = "Password of the existing user to authenticate with the domain"
  default = "P@ris20241812"
}


variable "wvd_base_url" {
  description = "The URL in which the Windows Virtual Desktop components exist"
  default     = "https://raw.githubusercontent.com/faroukfriha/azure-as-code/master/Windows%20Virtual%20Desktop"
}

variable "wvd_tenant_group_name" {
  description = "Name of the existing tenant group"
  default     = "Default Tenant Group"
}

variable "wvd_vm_size" {
  description = "Size of the session hosts to deploy"
  default     = "Standard_F4s_v2"
}

variable "wvd_rdbroker_url" {
  description = "URL of the RD Broker"
  default     = "https://rdbroker.wvd.microsoft.com"
}

variable "terraform_app_client_id" {
  description = "ID of the existing Terraform service principal"
  default     = "fcb860cb-7650-4b2c-9694-62058146f812"
}

variable "terraform_app_client_secret" {
  description = "Secret of the existing Terraform service principal"
  default = "Ulg_j[L31hyFfzO/ZY4V.NWHQXqugkB6"
}

variable "wvd_tenant_app_client_id" {
  description = "ID of the existing tenant service principal"
  default     = "cd42db33-c6e6-447c-9521-015e27033b8b"
}

variable "wvd_tenant_app_client_secret" {
  description = "Secret of the existing tenant service principal"
  default = "fZ9Zn4sLAsoDkf0ZK.qXD4=?HplfsiB?"
}


variable "wvd_is_service_principal" {
  description = "Is a service principal used for RDS connection"
  default     = "true"
}

variable "aad_tenant_id" {
  description = "ID of the existing Azure Active Directory tenant"
  default     = "32d48878-81e3-4a5a-8e18-888be6802ae0"
}

variable "subscription_id" {
  description = "ID of the existing Azure subscription"
  default     = "059df6d4-f0cf-4648-b149-9ec11ff9bce9"
}

variable "wvd_ou_path" {
  description = "Existing OU path to use during domain join"
  default = "OU=WVD HostPool,OU=Computers,OU=CCE,OU=EU,DC=pvcp,DC=intra"
}

variable "wvd_extension_log_analytics" {
  description = "Should log analytics agent be attached to all servers"
  default     = "true"
}

variable "wvd_os_disk_size" {
  description = "**OPTIONAL**: The size of the OS disk"
  default     = "128"
}

variable "wvd_image_name" {
  #description = "Name of the existing custom image to use"
  default     = "azfrcisdcp01-image-hp-01"
}

variable "wvd_virtual_network_peering_name" {
  #description = "Name of the existing custom image to use"
  default     = "peer-azprd-frc-wvd-to-core"
}

variable "hub_virtual_network_peering_name" {
  #description = "Name of the existing custom image to use"
  default     = "peer-azprd-frc-core-to-wvd-01"
}

variable "wvd_subnet_bastion_address_prefix" {
  #description = "Name of the existing custom image to use"
  default     = "10.99.27.224/27"
}

variable "wvd_public_ip_name" {
  #description = "Name of the existing custom image to use"
  default     = "pip-azprd-frc-bastion-wvd-01"
}

variable "wvd_bastion_name" {
  #description = "Name of the existing custom image to use"
  default     = "bas-azprd-frc-wvd-01"
}