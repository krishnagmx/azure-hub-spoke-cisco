# Pre-provision the control-plane identity so BYO VNet/UDR permissions exist
# BEFORE AKS attempts cluster creation (a system-assigned ID cannot do this).
resource "azurerm_user_assigned_identity" "controlplane" {
  name                = "${var.name}-controlplane-id"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}
resource "azurerm_user_assigned_identity" "kubelet" {
  name                = "${var.name}-kubelet-id"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}
resource "azurerm_role_assignment" "kubelet_operator" {
  scope                            = azurerm_user_assigned_identity.kubelet.id
  role_definition_name             = "Managed Identity Operator"
  principal_id                     = azurerm_user_assigned_identity.controlplane.principal_id
  skip_service_principal_aad_check = true
}
resource "azurerm_role_assignment" "aks_subnet_network" {
  # Custom private DNS integration requires Network Contributor on the VNet.
  scope                            = var.vnet_ids["prod"]
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_user_assigned_identity.controlplane.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.${replace(var.location, " ", "")}.azmk8s.io"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  for_each              = var.vnet_ids
  name                  = "${each.key}-aks-dns"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = each.value
  registration_enabled  = false
  tags                  = var.tags
}
resource "azurerm_role_assignment" "aks_private_dns" {
  scope                            = azurerm_private_dns_zone.aks.id
  role_definition_name             = "Private DNS Zone Contributor"
  principal_id                     = azurerm_user_assigned_identity.controlplane.principal_id
  skip_service_principal_aad_check = true
}
resource "azurerm_role_assignment" "aks_disk_encryption" {
  scope                            = var.disk_encryption_set_id
  role_definition_name             = "Reader"
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
  name                                = var.name
  location                            = var.location
  resource_group_name                 = var.resource_group_name
  dns_prefix                          = var.name
  sku_tier                            = "Standard"
  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = false
  private_dns_zone_id                 = azurerm_private_dns_zone.aks.id
  disk_encryption_set_id              = var.disk_encryption_set_id
  local_account_disabled              = true
  oidc_issuer_enabled                 = true
  workload_identity_enabled           = true
  azure_policy_enabled                = true
  role_based_access_control_enabled   = true
  automatic_channel_upgrade           = "patch"
  tags                                = var.tags

  default_node_pool {
    name                         = "system"
    vm_size                      = var.vm_size
    node_count                   = var.node_count
    max_pods                     = 110
    vnet_subnet_id               = var.subnet_id
    only_critical_addons_enabled = true
    os_disk_type                 = "Ephemeral"
    os_disk_size_gb              = 128
    enable_host_encryption       = true
    temporary_name_for_rotation  = "tempnode"
    tags                         = var.tags
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.controlplane.id]
  }
  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.kubelet.id
  }

  depends_on = [
    azurerm_role_assignment.aks_subnet_network,
    azurerm_role_assignment.aks_route_network,
    azurerm_role_assignment.aks_private_dns,
    azurerm_role_assignment.aks_disk_encryption,
    azurerm_role_assignment.kubelet_operator,
    azurerm_role_assignment.acr_pull,
    azurerm_private_dns_zone_virtual_network_link.aks,
  ]

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
  microsoft_defender { log_analytics_workspace_id = var.workspace_id }

  lifecycle { ignore_changes = [default_node_pool[0].node_count] }
}

resource "azurerm_kubernetes_cluster_node_pool" "workloads" {
  name                   = "workloads"
  kubernetes_cluster_id  = azurerm_kubernetes_cluster.this.id
  mode                   = "User"
  vm_size                = var.vm_size
  node_count             = var.workload_node_count
  vnet_subnet_id         = var.subnet_id
  max_pods               = 110
  os_disk_type           = "Ephemeral"
  os_disk_size_gb        = 128
  enable_host_encryption = true
  node_labels            = { workload = "application" }
  tags                   = var.tags
}

# ACR authorization is granted to kubelet, not the control-plane identity.
resource "azurerm_role_assignment" "acr_pull" {
  scope                            = var.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_user_assigned_identity.kubelet.principal_id
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
