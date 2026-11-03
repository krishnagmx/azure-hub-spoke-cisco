# Mock plan only: these documentation IPs/IDs are never deployed.
mock_provider "azurerm" {
  mock_resource "azurerm_kubernetes_cluster" {
    defaults = {
      kubelet_identity = [{
        object_id                 = "00000000-0000-0000-0000-000000000002"
        client_id                 = "00000000-0000-0000-0000-000000000003"
        user_assigned_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.ManagedIdentity/userAssignedIdentities/kubelet"
      }]
    }
  }
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000001"
    }
  }
}
mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = { tenant_id = "00000000-0000-0000-0000-000000000001" }
  }
}
variables {
  aks_admin_group_object_ids = ["00000000-0000-0000-0000-000000000004"]
  onprem_public_ip           = "198.51.100.20"
  vpn_shared_key             = "synthetic-test-only-key-00000000000000000000000000000000000000000000"
  disk_encryption_set_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/security-bootstrap/providers/Microsoft.Compute/diskEncryptionSets/test-only"
}
run "private_security_plan" {
  command = plan
  assert {
    condition     = output.security_configuration.aks.private_api && !output.security_configuration.aks.public_fqdn
    error_message = "AKS must expose only its private API."
  }
  assert {
    condition     = output.security_configuration.aks.sku == "Standard" && output.security_configuration.aks.system_only && output.security_configuration.aks.workload_pool_mode == "User"
    error_message = "Paid AKS must separate critical system addons from application workloads."
  }
  assert {
    condition     = output.security_configuration.aks.host_encryption && output.security_configuration.aks.os_disk_type == "Ephemeral" && output.security_configuration.aks.disk_encryption_set == var.disk_encryption_set_id
    error_message = "Host encryption, ephemeral OS disks and the supplied DES must be preserved."
  }
  assert {
    condition     = output.security_configuration.acr.sku == "Premium" && !output.security_configuration.acr.public_access && output.security_configuration.acr.quarantine && output.security_configuration.acr.zone_redundant
    error_message = "ACR must remain private, Premium, zone redundant and quarantine new images."
  }
  assert {
    condition     = output.security_configuration.firewall.sku == "Premium" && output.security_configuration.firewall.threat_mode == "Deny" && output.security_configuration.firewall.intrusion_mode == "Deny"
    error_message = "Firewall must enforce threat and intrusion blocking."
  }
}
