output "id" { value = azurerm_key_vault.this.id }
output "name" { value = azurerm_key_vault.this.name }
output "private_endpoint_ip" { value = azurerm_private_endpoint.vault.private_service_connection[0].private_ip_address }
