data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

resource "azurerm_resource_group" "this" {
  name     = "${local.prefix}-rg"
  location = var.location
  tags     = local.tags
}

module "monitoring" {
  source              = "../../modules/monitoring"
  name                = "${local.prefix}-law"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  tags                = local.tags
}

module "network" {
  source                  = "../../modules/network"
  name_prefix             = local.prefix
  resource_group_name     = azurerm_resource_group.this.name
  location                = var.location
  hub_cidr                = local.net.hub
  prod_cidr               = local.net.prod
  nonprod_cidr            = local.net.nonprod
  gateway_subnet_cidr     = cidrsubnet(local.net.hub, 11, 0) # /27
  firewall_subnet_cidr    = cidrsubnet(local.net.hub, 10, 4) # /26 -> x.x.1.0/26
  shared_subnet_cidr      = cidrsubnet(local.net.hub, 8, 2)  # /24
  prod_aks_subnet_cidr    = cidrsubnet(local.net.prod, 6, 0) # /22
  prod_pe_subnet_cidr     = cidrsubnet(local.net.prod, 8, 4) # /24
  nonprod_app_subnet_cidr = cidrsubnet(local.net.nonprod, 6, 0)
  nonprod_pe_subnet_cidr  = cidrsubnet(local.net.nonprod, 8, 4)
  nonprod_vm_subnet_cidr  = cidrsubnet(local.net.nonprod, 8, 8)
  onprem_public_ip        = var.onprem_public_ip
  onprem_lan_cidr         = "172.16.10.0/24"
  vpn_shared_key          = var.vpn_shared_key
  allowed_egress_fqdns    = concat(local.aks_egress_fqdns, [azurerm_container_registry.this.login_server, "*.data.azurecr.io"])
  tags                    = local.tags
}

resource "azurerm_container_registry" "this" {
  name                          = "acr${var.environment}${local.unique_id}"
  resource_group_name           = azurerm_resource_group.this.name
  location                      = var.location
  sku                           = "Basic"
  admin_enabled                 = false
  public_network_access_enabled = true # GitHub-hosted runners push using Azure RBAC.
  tags                          = local.tags
}

module "keyvault" {
  source                     = "../../modules/keyvault"
  name                       = "kv${var.environment}${local.unique_id}"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = var.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  private_endpoint_subnet_id = module.network.prod_pe_subnet_id
  vnet_ids                   = module.network.vnet_ids
  tags                       = local.tags
  depends_on                 = [module.network]
}

module "aks" {
  source                  = "../../modules/aks"
  name                    = "${local.prefix}-aks"
  location                = var.location
  resource_group_name     = azurerm_resource_group.this.name
  subnet_id               = module.network.prod_aks_subnet_id
  route_table_id          = module.network.prod_route_table_id
  workspace_id            = module.monitoring.workspace_id
  acr_id                  = azurerm_container_registry.this.id
  tenant_id               = data.azuread_client_config.current.tenant_id
  admin_group_object_ids  = var.aks_admin_group_object_ids
  private_cluster_enabled = var.private_aks
  authorized_ip_ranges    = var.aks_authorized_ip_ranges
  node_count              = var.aks_node_count
  tags                    = local.tags
  depends_on              = [module.network]
}

resource "azurerm_role_assignment" "kv_workload_read" {
  scope                            = module.keyvault.id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = module.aks.app_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_monitor_diagnostic_setting" "vpn" {
  name                       = "vpn-to-law"
  target_resource_id         = module.network.vpn_gateway_id
  log_analytics_workspace_id = module.monitoring.workspace_id
  enabled_log { category = "GatewayDiagnosticLog" }
  enabled_log { category = "TunnelDiagnosticLog" }
  enabled_log { category = "IKEDiagnosticLog" }
  enabled_log { category = "RouteDiagnosticLog" }
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "firewall-to-law"
  target_resource_id         = module.network.firewall_id
  log_analytics_workspace_id = module.monitoring.workspace_id
  enabled_log { category = "AzureFirewallApplicationRule" }
  enabled_log { category = "AzureFirewallNetworkRule" }
  enabled_log { category = "AzureFirewallDnsProxy" }
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "keyvault-to-law"
  target_resource_id         = module.keyvault.id
  log_analytics_workspace_id = module.monitoring.workspace_id
  enabled_log { category = "AuditEvent" }
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "aks-to-law"
  target_resource_id         = module.aks.id
  log_analytics_workspace_id = module.monitoring.workspace_id
  enabled_log { category = "kube-audit-admin" }
  enabled_log { category = "kube-apiserver" }
  enabled_log { category = "cluster-autoscaler" }
  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Optional test VM: no public IP, no password, no direct SSH from internet.
resource "azurerm_network_interface" "test" {
  count               = var.enable_test_vm ? 1 : 0
  name                = "${local.prefix}-test-nic"
  resource_group_name = azurerm_resource_group.this.name
  location            = var.location
  tags                = local.tags
  ip_configuration {
    name                          = "internal"
    subnet_id                     = module.network.nonprod_vm_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_linux_virtual_machine" "test" {
  count                           = var.enable_test_vm ? 1 : 0
  name                            = "${local.prefix}-testvm"
  resource_group_name             = azurerm_resource_group.this.name
  location                        = var.location
  size                            = "Standard_B1s"
  admin_username                  = "azureuser"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.test[0].id]
  custom_data                     = base64encode(file("${path.module}/../../cloud-init/test-vm.yaml"))
  tags                            = local.tags
  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  boot_diagnostics {}
}
