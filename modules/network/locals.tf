locals {
  # NSGs are intentionally absent from GatewaySubnet and AzureFirewallSubnet.
  spoke_subnets = {
    prod_aks    = azurerm_subnet.prod_aks.id
    prod_pe     = azurerm_subnet.prod_pe.id
    nonprod_app = azurerm_subnet.nonprod_app.id
    nonprod_pe  = azurerm_subnet.nonprod_pe.id
    nonprod_vm  = azurerm_subnet.nonprod_vm.id
  }
}
