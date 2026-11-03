variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "tenant_id" { type = string }
variable "private_endpoint_subnet_id" { type = string }
variable "vnet_ids" { type = map(string) }
variable "tags" { type = map(string) }
