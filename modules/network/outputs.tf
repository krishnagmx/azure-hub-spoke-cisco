output "vnet_ids" {
  value = {
    hub     = azurerm_virtual_network.hub.id
    prod    = azurerm_virtual_network.prod.id
    nonprod = azurerm_virtual_network.nonprod.id
  }
}
output "prod_aks_subnet_id" { value = azurerm_subnet.prod_aks.id }
output "prod_pe_subnet_id" { value = azurerm_subnet.prod_pe.id }
output "nonprod_vm_subnet_id" { value = azurerm_subnet.nonprod_vm.id }
output "nonprod_vm_nsg_id" { value = azurerm_network_security_group.spoke["nonprod_vm"].id }
output "vpn_gateway_id" { value = azurerm_virtual_network_gateway.vpn.id }
output "vpn_connection_id" { value = azurerm_virtual_network_gateway_connection.cisco.id }
output "vpn_public_ip" { value = azurerm_public_ip.vpn.ip_address }
output "firewall_id" { value = azurerm_firewall.this.id }
output "firewall_private_ip" { value = azurerm_firewall.this.ip_configuration[0].private_ip_address }

output "prod_route_table_id" { value = azurerm_route_table.spoke["prod"].id }
output "security_configuration" {
  value = {
    sku            = azurerm_firewall.this.sku_tier
    threat_mode    = azurerm_firewall_policy.this.threat_intelligence_mode
    intrusion_mode = azurerm_firewall_policy.this.intrusion_detection[0].mode
  }
}
