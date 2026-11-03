variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "subnet_id" { type = string }
variable "workspace_id" { type = string }
variable "acr_id" { type = string }
variable "tenant_id" { type = string }
variable "admin_group_object_ids" { type = list(string) }
variable "node_count" {
  type    = number
  default = 2
}
variable "vm_size" {
  type    = string
  default = "Standard_D2as_v5"
}
variable "private_cluster_enabled" {
  type    = bool
  default = false
}
variable "authorized_ip_ranges" {
  type    = list(string)
  default = null
}
variable "tags" { type = map(string) }

variable "route_table_id" { type = string }
