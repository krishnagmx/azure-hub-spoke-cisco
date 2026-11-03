variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}
variable "location" {
  type    = string
  default = "westeurope"
}
variable "project" {
  type    = string
  default = "hybridlz"
}
variable "owner" {
  type    = string
  default = "cloud-platform"
}
variable "cost_center" {
  type    = string
  default = "cloud-poc"
}
variable "extra_tags" {
  type    = map(string)
  default = {}
}
variable "vpn_shared_key" {
  type      = string
  sensitive = true
}
variable "onprem_public_ip" {
  type        = string
  description = "Real reachable public IP forwarding UDP 500 and 4500 to Cisco."
}
variable "aks_admin_group_object_ids" {
  type = list(string)
  validation {
    condition     = length(var.aks_admin_group_object_ids) > 0 && alltrue([for id in var.aks_admin_group_object_ids : can(regex("^[0-9a-fA-F-]{36}$", id))])
    error_message = "Supply at least one AKS administrator Entra group object UUID."
  }
}
variable "disk_encryption_set_id" {
  type        = string
  description = "Security-team managed, same-region Disk Encryption Set resource ID. Required before a deployable plan can be created."
}
variable "acr_replica_location" {
  type    = string
  default = "northeurope"
}
variable "aks_workload_node_count" {
  type    = number
  default = 2
}
variable "aks_node_count" {
  type    = number
  default = 2
}
variable "enable_test_vm" {
  type    = bool
  default = false
}
variable "ssh_public_key" {
  type    = string
  default = ""
}
