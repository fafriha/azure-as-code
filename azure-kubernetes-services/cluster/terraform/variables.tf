variable "subscription_id" {
    default = ""
}

variable "node_resource_group_name" {
    default = "aksnodes-rg"
}

variable "service_principal_client_id" {
    default = ""
}

variable "service_principal_secret" {
    default = ""
}

variable "service_principal_object_id" {
    default = ""
}
variable "agent_count" {
    default = 3
}

variable "ssh_public_key" {
    default = ""
}

variable "dns_prefix" {
    default = ""
}

variable cluster_name {
    default = ""
}

variable log_analytics_workspace_name {
    default = ""
}