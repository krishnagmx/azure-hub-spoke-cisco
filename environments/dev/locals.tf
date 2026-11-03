locals {
  prefix    = "${var.project}-${var.environment}"
  unique_id = substr(sha256(data.azurerm_client_config.current.subscription_id), 0, 13)
  tags = merge(var.extra_tags, {
    environment = var.environment
    owner       = var.owner
    costCenter  = var.cost_center
    project     = var.project
    managedBy   = "terraform"
  })
  net = var.environment == "prod" ? {
    hub     = "10.0.0.0/16"
    prod    = "10.10.0.0/16"
    nonprod = "10.20.0.0/16"
    } : {
    hub     = "10.100.0.0/16"
    prod    = "10.110.0.0/16"
    nonprod = "10.120.0.0/16"
  }
  # Restrict workload egress to AKS dependencies; review on each AKS upgrade.
  aks_egress_fqdns = [
    "*.hcp.${replace(var.location, " ", "")}.azmk8s.io",
    "mcr.microsoft.com", "*.data.mcr.microsoft.com", "mcr-0001.mcr-msedge.net",
    "management.azure.com", "login.microsoftonline.com", "packages.microsoft.com",
    "acs-mirror.azureedge.net", "packages.aks.azure.com",
    "*.blob.core.windows.net", "*.servicebus.windows.net",
    "*.ods.opinsights.azure.com", "*.oms.opinsights.azure.com",
    "*.monitor.azure.com", "*.ingest.monitor.azure.com",
    "security.ubuntu.com", "azure.archive.ubuntu.com",
    "snapshot.ubuntu.com", "changelogs.ubuntu.com"
  ]
}
