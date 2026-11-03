output "resource_group_name" { value = azurerm_resource_group.this.name }
output "vpn_public_ip" { value = module.network.vpn_public_ip }
output "firewall_private_ip" { value = module.network.firewall_private_ip }
output "aks_name" { value = module.aks.name }
output "acr_name" { value = azurerm_container_registry.this.name }
output "keyvault_name" { value = module.keyvault.name }
output "keyvault_private_ip" { value = module.keyvault.private_endpoint_ip }
output "workload_client_id" { value = module.aks.app_client_id }
output "tenant_id" { value = data.azurerm_client_config.current.tenant_id }
output "test_vm_private_ip" { value = try(azurerm_network_interface.test[0].private_ip_address, null) }

output "security_configuration" {
  value = {
    aks      = module.aks.security_configuration
    firewall = module.network.security_configuration
    acr = {
      sku            = azurerm_container_registry.this.sku
      public_access  = azurerm_container_registry.this.public_network_access_enabled
      quarantine     = azurerm_container_registry.this.quarantine_policy_enabled
      zone_redundant = azurerm_container_registry.this.zone_redundancy_enabled
    }
  }
}
