variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "hub_cidr" { type = string }
variable "prod_cidr" { type = string }
variable "nonprod_cidr" { type = string }
variable "gateway_subnet_cidr" { type = string }
variable "firewall_subnet_cidr" { type = string }
variable "shared_subnet_cidr" { type = string }
variable "prod_aks_subnet_cidr" { type = string }
variable "prod_pe_subnet_cidr" { type = string }
variable "nonprod_app_subnet_cidr" { type = string }
variable "nonprod_pe_subnet_cidr" { type = string }
variable "nonprod_vm_subnet_cidr" { type = string }
variable "onprem_lan_cidr" { type = string }
variable "onprem_public_ip" { type = string }
variable "vpn_shared_key" {
  type      = string
  sensitive = true
}
variable "azure_bgp_asn" {
  type    = number
  default = 65010
}
variable "onprem_bgp_asn" {
  type    = number
  default = 65020
}
variable "azure_bgp_ip" {
  type    = string
  default = "169.254.21.1"
}
variable "onprem_bgp_ip" {
  type    = string
  default = "169.254.21.2"
}
variable "allowed_egress_fqdns" { type = list(string) }
variable "tags" { type = map(string) }
