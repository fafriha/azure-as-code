################################################### Hub ################################################

variable "hub_resource_group_name" {
  description = "[Mandatory] [Import] Enter the name of your existing hub resource group which contains or allows you to communicate with your core resources (domain controllers, dns servers, firewall, ...)"
  default     = ""
}

variable "hub_virtual_network_name" {
  description = "[Mandatory] [Import] Enter the name of your hub virtual network to which your domain controllers are connected to"
  default     = ""
}

variable "hub_virtual_network_peering_name" {
  description = "[Mandatory] [Create] Enter the name of the peering that will connect your hub virtual network to the Windows Virtual Desktop virtual network"
  default     = ""
}

################################################### Windows Virtual Desktop ################################################

variable "lab_resource_group_name" {
  description = "[Mandatory] [Create] Enter the name of the resource group to that will group all Windows Virtual Desktop resources."
  default     = ""
}

variable "lab_location" {
  description = "[Mandatory] [Import] Enter the Azure region in which all resources will deployed."
  default     = ""
}

variable "lab_name" {
  default     = ""
}

variable "lab_virtual_network_name" {
  description = "[Mandatory] [Create] Enter the name of the virtual network that will host all session hosts."
  default     = ""
}

variable "lab_virtual_network_address_space" {
  description = "[Mandatory] [Create] Enter the address space of the above virtual network."
  default     = ""
}

variable "lab_dns_servers" {
  description = "[Mandatory] [Import] Enter the IP address of your DNS server(s) to allow name resolution from all session hosts."
  default     = ""
}

variable "lab_virtual_network_peering_name" {
  description = "[Mandatory] [Create] Enter the name of the peering that will connect the Windows Virtual Desktop virtual network to your hub virtual network."
  default     = ""
}

variable "lab_subnet_name" {
  description = "[Mandatory] [Create] Enter the name of the subnet that will host all Windows 10 multi-session hosts."
  default     = ""
}

variable "lab_subnet_address_prefix" {
  description = "[Mandatory] [Create] Enter the address space of the clients above."
  default     = ""
}


variable "lab_storage_account_name" {
  description = "[Mandatory] [Create] Enter the name of the storage account that will host all user profiles."
  default     = ""
}

variable "lab_vm_count" {
  description = "[Mandatory] [Create] Enter the number of session hosts you would like to create."
  default     = 1
}

variable "lab_vm_prefix" {
  description = "[Mandatory] [Create] Enter the prefix name (less than 13 characters) that will be used to generate session hosts' name."
  default     = ""
}

variable "lab_domain_name" {
  description = "[Mandatory] [Import] Enter the name of your domain to join the sesion hosts to."
  default     = ""
}

variable "lab_domain_join_username" {
  description = "[Mandatory] [Import] Enter the username of your service account that will be used to join all session hosts to the domain."
  default     = ""
}

variable "lab_domain_join_password" {
  description = "[Mandatory] [Import] Enter the password of your service account that will be used to join all session hosts to the domain."
  default = ""
}

variable "lab_local_admin_username" {
  description = "[Mandatory] [Import] Enter the username of the account that wil be the local administrator of all session hosts."
  default     = ""
}

variable "lab_local_admin_password" {
  description = "[Mandatory] [Import] Enter the password of the account that wil be the local administrator of ell session hosts."
  default = ""
}

variable "lab_vm_size" {
  description = "[Mandatory] [Create] Enter the size of the session hosts to deploy."
  default     = ""
}

################################################### Global ################################################

variable "terraform_app_id" {
  description = "[Mandatory] [Import] Enter the application (client) ID of the Terraform app you created."
  default     = ""
}

variable "terraform_app_secret" {
  description = "[Mandatory] [Import] Enter the application (client) secret of the Terraform app you created"
  default = ""
}

variable "aad_tenant_id" {
  description = "[Mandatory] [Import] Enter the ID of your Azure Active Directory tenant."
  default     = ""
}

variable "subscription_id" {
  description = "[Mandatory] [Import] Enter the Id of your subscription in which you want to deploy all resources."
  default     = ""
}