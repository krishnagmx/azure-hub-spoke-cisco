# Pre-provision the control-plane identity so BYO VNet/UDR permissions exist
# BEFORE AKS attempts cluster creation (a system-assigned ID cannot do this).
resource "azurerm_user_assigned_identity" "controlplane" {
  name                = "${var.name}-controlplane-id"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}
resource "azurerm_role_assignment" "aks_subnet_network" {
  scope                            = var.subnet_id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_user_assigned_identity.controlplane.principal_id
  skip_service_principal_aad_check = true
}
resource "azurerm_role_assignment" "aks_route_network" {
  scope                            = var.route_table_id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_user_assigned_identity.controlplane.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_kubernetes_cluster" "this" {
  name                              = var.name
  location                          = var.location
  resource_group_name               = var.resource_group_name
  dns_prefix                        = var.name
  sku_tier                          = "Free"
  private_cluster_enabled           = var.private_cluster_enabled
  local_account_disabled            = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  azure_policy_enabled              = true
  role_based_access_control_enabled = true
  automatic_channel_upgrade         = "patch"
  tags                              = var.tags

  default_node_pool {
    name                         = "system"
    vm_size                      = var.vm_size
    node_count                   = var.node_count
    max_pods                     = 110
    vnet_subnet_id               = var.subnet_id
    only_critical_addons_enabled = false
    temporary_name_for_rotation  = "tempnode"
    tags                         = var.tags
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.controlplane.id]
  }

  depends_on = [azurerm_role_assignment.aks_subnet_network, azurerm_role_assignment.aks_route_network]

  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
    tenant_id              = var.tenant_id
    admin_group_object_ids = var.admin_group_object_ids
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay" # Conserves spoke addresses for nodes/VMs.
    network_policy      = "azure"
    outbound_type       = "userDefinedRouting"
    service_cidr        = "10.240.0.0/16"
    dns_service_ip      = "10.240.0.10"
    pod_cidr            = "10.244.0.0/16"
  }

  oms_agent { log_analytics_workspace_id = var.workspace_id }
  key_vault_secrets_provider { secret_rotation_enabled = true }

  api_server_access_profile {
    authorized_ip_ranges = var.private_cluster_enabled ? null : var.authorized_ip_ranges
  }

  lifecycle { ignore_changes = [default_node_pool[0].node_count] }
}

# ACR authorization is granted to kubelet, not the control-plane identity.
resource "azurerm_role_assignment" "acr_pull" {
  scope                            = var.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_user_assigned_identity" "app" {
  name                = "${var.name}-app-id"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "app" {
  name                = "${var.name}-app-federation"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.app.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject             = local.workload_serviceaccount_subject
}
