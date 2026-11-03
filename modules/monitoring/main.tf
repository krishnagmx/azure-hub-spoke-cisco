resource "azurerm_log_analytics_workspace" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = local.log_analytics_sku
  retention_in_days   = var.retention_days
  daily_quota_gb      = 1
  tags                = var.tags
}
