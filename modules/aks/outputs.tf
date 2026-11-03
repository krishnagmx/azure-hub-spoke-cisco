output "id" { value = azurerm_kubernetes_cluster.this.id }
output "name" { value = azurerm_kubernetes_cluster.this.name }
output "fqdn" { value = azurerm_kubernetes_cluster.this.fqdn }
output "app_principal_id" { value = azurerm_user_assigned_identity.app.principal_id }
output "app_client_id" { value = azurerm_user_assigned_identity.app.client_id }
