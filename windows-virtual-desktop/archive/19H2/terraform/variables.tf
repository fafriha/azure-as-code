################################################### Hub ################################################

variable "hub_resource_group_name" {
  description = "[Mandatory] [Import] Enter the name of your existing hub resource group which contains or allows you to communicate with your core resources (domain controllers, dns servers, firewall, ...)"
  default     = ""
}

# variable "hub_default_route_table_name" {
#   description = "[Optional] [Import] Enter the name of the default route table which redirects the external traffic to your firewall"
#   default = ""
# }

variable "hub_virtual_network_name" {
  description = "[Mandatory] [Import] Enter the name of your hub virtual network to which your domain controllers are connected to"
  default     = ""
}

variable "hub_virtual_network_peering_name" {
  description = "[Mandatory] [Create] Enter the name of the peering that will connect your hub virtual network to the Windows Virtual Desktop virtual network"
  default     = ""
}

################################################### Windows Virtual Desktop ################################################

variable "wvd_resource_group_name" {
  description = "[Mandatory] [Create] Enter the name of the resource group to that will group all Windows Virtual Desktop resources."
  default     = ""
}

variable "wvd_location" {
  description = "[Mandatory] [Import] Enter the Azure region in which all resources will deployed."
  default     = ""
}

variable "wvd_network_security_group_name" {
  description = "[Mandatory] [Create] Enter the name of the network security group that will secure the incoming and outgoing hosts internal traffic."
  default     = ""
}

variable "wvd_automation_account_name" {
  description = "[Mandatory] [Create] Enter the name of the automation account that will be part of the auto scaling tool."
  default     = ""
}

variable "wvd_webhook_name" {
  description = "[Mandatory] [Create] Enter the name of the webhook that will publish the runbook."
  default     = ""
}

variable "wvd_time_before_logoff" {
  description = "[Mandatory] [Create] Enter the number of seconds to wait before automatically signing out users. If set to 0, users will be signed out immediately"
  default     = ""
}

variable "wvd_logoff_message_body" {
  description = "[Mandatory] [Create] Enter the body of the message to send to the user before they will be forced to sign out."
  default     = ""
}

variable "wvd_logoff_message_title" {
  description = "[Mandatory] [Create] Enter the title of the message to send to the user before they will be forced to sign out."
  default     = ""
}

variable "wvd_maintenance_tag_name" {
  description = "[Mandatory] [Create] Enter the name of the tag that will be associated with the session hosts you don't want to be managed by the scaling tool."
  default     = ""
}

variable "wvd_minimum_session_host" {
  description = "[Mandatory] [Create] Enter the minimum number of session hosts you want to keep running during off-peak hours."
  default     = ""
}

variable "wvd_time_difference" {
  description = "[Mandatory] [Create] Enter the time difference between your local time and UTC in hours (e.g. +1:00)."
  default     = ""
}

variable "wvd_max_session_per_cpu" {
  description = "[Mandatory] [Create] Enter the maximum number of sessions per CPU that will be used as a threshold to determine when new session hosts need to be started during peak hours."
  default     = ""
}

variable "wvd_begin_peak_time" {
  description = "[Mandatory] [Create] Enter the start time for peak hours in your local time (e.g. 9:00)."
  default     = ""
}

variable "wvd_end_peak_time" {
  description = "[Mandatory] [Create] Enter the end time for peak hours in local time (e.g. 18:00)."
  default     = ""
}

variable "wvd_logic_app_workflow_name" {
  description = "[Mandatory] [Create] Enter the name of the logic app that will be part of the scaling tool."
  default     = ""
}

variable "wvd_logic_app_trigger_recurrence" {
  description = "[Mandatory] [Create] Enter how often you would like to run the scaling tool in minutes (e.g. 15)"
  default     = ""
}

variable "wvd_log_analytics_workspace_name" {
  description = "[Mandatory] [Create] Enter the name of the log analytics workspace that will be part of the monitoring solution."
  default     = ""
}

variable "wvd_virtual_network_name" {
  description = "[Mandatory] [Create] Enter the name of the virtual network that will host all session hosts."
  default     = ""
}

variable "wvd_virtual_network_address_space" {
  description = "[Mandatory] [Create] Enter the address space of the above virtual network."
  default     = ""
}

variable "wvd_dns_servers" {
  description = "[Mandatory] [Import] Enter the IP address of your DNS server(s) to allow name resolution from all session hosts."
  default     = ""
}

variable "wvd_virtual_network_peering_name" {
  description = "[Mandatory] [Create] Enter the name of the peering that will connect the Windows Virtual Desktop virtual network to your hub virtual network."
  default     = ""
}

variable "wvd_bastion_subnet_address_prefix" {
  description = "[Mandatory] [Create] Enter the address space of the bastion subnet."
  default     = ""
}

variable "wvd_clients_subnet_name" {
  description = "[Mandatory] [Create] Enter the name of the subnet that will host all Windows 10 multi-session hosts."
  default     = ""
}

variable "wvd_clients_subnet_address_prefix" {
  description = "[Mandatory] [Create] Enter the address space of the clients above."
  default     = ""
}

variable "wvd_public_ip_name" {
  description = "[Mandatory] [Create] Enter the name of the public IP address that will be assigned to the bastion host."
  default     = ""
}

variable "wvd_bastion_name" {
  description = "[Mandatory] [Create] Enter the name of the bastion host that will allow you to connect securely to all session hosts."
  default     = ""
}

variable "wvd_storage_account_name" {
  description = "[Mandatory] [Create] Enter the name of the storage account that will host all user profiles."
  default     = ""
}

variable "wvd_rdsh_count" {
  description = "[Mandatory] [Create] Enter the number of session hosts you would like to create."
  default     = 1
}

variable "wvd_host_pool_name" {
  description = "[Mandatory] [Import] Enter the name of your Windows Virtual Desktop host pool to join the session hosts to."
  default     = ""
}

variable "wvd_vm_prefix" {
  description = "[Mandatory] [Create] Enter the prefix name (less than 13 characters) that will be used to generate session hosts' name."
  default     = ""
}

variable "wvd_tenant_name" {
  description = "[Mandatory] [Import] Enter the name of your Windows Virtual Desktop tenant / workspace."
  default     = ""
}

variable "wvd_registration_expiration_hours" {
  description = "[Mandatory] [Create] Enter the expiration time of the token that will be generated to register all session hosts to the hostpool."
  default     = ""
}

variable "wvd_key_vault_name" {
  description = "[Mandatory] [Create] Enter the name of the key vault that will store all passwords and secrets securely."
  default     = ""
}

variable "wvd_domain_name" {
  description = "[Mandatory] [Import] Enter the name of your domain to join the sesion hosts to."
  default     = ""
}

variable "wvd_domain_join_username" {
  description = "[Mandatory] [Import] Enter the username of your service account that will be used to join all session hosts to the domain."
  default     = ""
}

variable "wvd_domain_join_password" {
  description = "[Mandatory] [Import] Enter the password of your service account that will be used to join all session hosts to the domain."
  default = ""
}

variable "wvd_local_admin_username" {
  description = "[Mandatory] [Import] Enter the username of the account that wil be the local administrator of all session hosts."
  default     = ""
}

variable "wvd_local_admin_password" {
  description = "[Mandatory] [Import] Enter the password of the account that wil be the local administrator of ell session hosts."
  default = ""
}

variable "wvd_tenant_group_name" {
  description = "[Mandatory] [Import] Enter the name of your Windows Virtual Desktop tenant / workspace group."
  default     = ""
}

variable "wvd_vm_size" {
  description = "[Mandatory] [Create] Enter the size of the session hosts to deploy."
  default     = ""
}

variable "wvd_tenant_app_id" {
  description = "[Mandatory] [Import] Enter the application (client) ID of the Windows Virtual Desktop tenant app you created."
  default     = ""
}

variable "wvd_tenant_app_secret" {
  description = "[Mandatory] [Import] Enter the application (client) secret of the Windows Virtual Desktop tenant app you created."
  default = ""
}

variable "wvd_ou_path" {
  description = "[Mandatory] [Import] Enter the distinguished name of the OU in your domain in which you would like put the session hosts."
  default = ""
}

################################################### Global ################################################

variable "global_terraform_app_id" {
  description = "[Mandatory] [Import] Enter the application (client) ID of the Terraform app you created."
  default     = ""
}

variable "global_terraform_app_secret" {
  description = "[Mandatory] [Import] Enter the application (client) secret of the Terraform app you created"
  default = ""
}

variable "global_aad_tenant_id" {
  description = "[Mandatory] [Import] Enter the ID of your Azure Active Directory tenant."
  default     = ""
}

variable "global_subscription_id" {
  description = "[Mandatory] [Import] Enter the Id of your subscription in which you want to deploy all resources."
  default     = ""
}