output "id" { value = azurerm_kubernetes_cluster.this.id }
output "name" { value = azurerm_kubernetes_cluster.this.name }
output "fqdn" { value = azurerm_kubernetes_cluster.this.private_fqdn }
output "app_principal_id" { value = azurerm_user_assigned_identity.app.principal_id }
output "app_client_id" { value = azurerm_user_assigned_identity.app.client_id }
output "security_configuration" {
  value = {
    private_api         = azurerm_kubernetes_cluster.this.private_cluster_enabled
    public_fqdn         = azurerm_kubernetes_cluster.this.private_cluster_public_fqdn_enabled
    sku                 = azurerm_kubernetes_cluster.this.sku_tier
    disk_encryption_set = azurerm_kubernetes_cluster.this.disk_encryption_set_id
    system_only         = azurerm_kubernetes_cluster.this.default_node_pool[0].only_critical_addons_enabled
    os_disk_type        = azurerm_kubernetes_cluster.this.default_node_pool[0].os_disk_type
    host_encryption     = azurerm_kubernetes_cluster.this.default_node_pool[0].enable_host_encryption
    workload_pool_mode  = azurerm_kubernetes_cluster_node_pool.workloads.mode
  }
}
