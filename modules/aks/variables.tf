variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "subnet_id" { type = string }
variable "vnet_ids" { type = map(string) }
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
  default = "Standard_D4ds_v5"
}
variable "workload_node_count" {
  type    = number
  default = 2
}
variable "disk_encryption_set_id" {
  type        = string
  description = "Existing same-region Disk Encryption Set, with its managed identity authorized on its customer-managed key. Ephemeral OS disks use platform-managed encryption; DES applies to supported managed disks."
  validation {
    condition     = can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Compute/diskEncryptionSets/[^/]+$", var.disk_encryption_set_id))
    error_message = "Supply a full Disk Encryption Set resource ID from the security bootstrap."
  }
}
variable "tags" { type = map(string) }

variable "route_table_id" { type = string }
