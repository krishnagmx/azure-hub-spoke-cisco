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
  type    = list(string)
  default = []
}
variable "private_aks" {
  type    = bool
  default = false
}
variable "aks_authorized_ip_ranges" {
  type    = list(string)
  default = null
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
