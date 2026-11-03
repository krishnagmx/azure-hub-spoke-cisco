resource "azurerm_virtual_network" "hub" {
  name                = "${var.name_prefix}-hub-vnet"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.hub_cidr]
  tags                = var.tags
}
resource "azurerm_virtual_network" "prod" {
  name                = "${var.name_prefix}-prod-vnet"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.prod_cidr]
  tags                = var.tags
}
resource "azurerm_virtual_network" "nonprod" {
  name                = "${var.name_prefix}-nonprod-vnet"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = [var.nonprod_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.gateway_subnet_cidr]
}
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.firewall_subnet_cidr]
}
resource "azurerm_subnet" "shared" {
  name                 = "snet-shared"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.shared_subnet_cidr]
}
resource "azurerm_subnet" "prod_aks" {
  name                 = "snet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.prod.name
  address_prefixes     = [var.prod_aks_subnet_cidr]
}
resource "azurerm_subnet" "prod_pe" {
  name                                      = "snet-private-endpoints"
  resource_group_name                       = var.resource_group_name
  virtual_network_name                      = azurerm_virtual_network.prod.name
  address_prefixes                          = [var.prod_pe_subnet_cidr]
  private_endpoint_network_policies_enabled = true
}
resource "azurerm_subnet" "nonprod_app" {
  name                 = "snet-app"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.nonprod.name
  address_prefixes     = [var.nonprod_app_subnet_cidr]
}
resource "azurerm_subnet" "nonprod_pe" {
  name                                      = "snet-private-endpoints"
  resource_group_name                       = var.resource_group_name
  virtual_network_name                      = azurerm_virtual_network.nonprod.name
  address_prefixes                          = [var.nonprod_pe_subnet_cidr]
  private_endpoint_network_policies_enabled = true
}
resource "azurerm_subnet" "nonprod_vm" {
  name                 = "snet-vm-test"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.nonprod.name
  address_prefixes     = [var.nonprod_vm_subnet_cidr]
}

resource "azurerm_network_security_group" "shared" {
  name                = "${var.name_prefix}-shared-nsg"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}
resource "azurerm_subnet_network_security_group_association" "shared" {
  subnet_id                 = azurerm_subnet.shared.id
  network_security_group_id = azurerm_network_security_group.shared.id
}

resource "azurerm_network_security_group" "spoke" {
  for_each            = local.spoke_subnets
  name                = "${var.name_prefix}-${replace(each.key, "_", "-")}-nsg"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}
resource "azurerm_subnet_network_security_group_association" "spoke" {
  for_each                  = local.spoke_subnets
  subnet_id                 = each.value
  network_security_group_id = azurerm_network_security_group.spoke[each.key].id
}

# AKS requires intra-VNet and Azure platform traffic; restrictive pod-to-pod
# controls belong in Kubernetes NetworkPolicy, not blanket subnet NSG denies.
resource "azurerm_network_security_rule" "aks_vnet" {
  name                        = "AllowAKSVNet"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.prod_cidr
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.spoke["prod_aks"].name
}
resource "azurerm_network_security_rule" "vm_onprem" {
  name                        = "AllowOnPremHTTP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = var.onprem_lan_cidr
  destination_address_prefix  = var.nonprod_vm_subnet_cidr
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.spoke["nonprod_vm"].name
}
resource "azurerm_network_security_rule" "pe_aks" {
  name                        = "AllowAKSPrivateLinkHTTPS"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.prod_aks_subnet_cidr
  destination_address_prefix  = var.prod_pe_subnet_cidr
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.spoke["prod_pe"].name
}
resource "azurerm_network_security_rule" "pe_onprem_admin" {
  name                        = "AllowOnPremAdminHTTPS"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.onprem_lan_cidr
  destination_address_prefix  = var.prod_pe_subnet_cidr
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.spoke["prod_pe"].name
}
resource "azurerm_network_security_rule" "pe_deny" {
  name                        = "DenyOtherPEInbound"
  priority                    = 400
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.spoke["prod_pe"].name
}

# Default NSG AllowVNetInBound is broader than the tested application requires.
resource "azurerm_network_security_rule" "deny_other_spoke_inbound" {
  for_each                    = toset(["nonprod_app", "nonprod_pe", "nonprod_vm"])
  name                        = "DenyOtherInbound"
  priority                    = 400
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.spoke[each.value].name
}
resource "azurerm_network_security_rule" "deny_shared_inbound" {
  name                        = "DenyOtherInbound"
  priority                    = 400
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.shared.name
}

resource "azurerm_public_ip" "vpn" {
  name                = "${var.name_prefix}-vpn-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}
resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "${var.name_prefix}-vpngw"
  resource_group_name = var.resource_group_name
  location            = var.location
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  active_active       = false
  enable_bgp          = true
  tags                = var.tags
  ip_configuration {
    name                          = "vpnconfig"
    public_ip_address_id          = azurerm_public_ip.vpn.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }
  bgp_settings {
    asn = var.azure_bgp_asn
    peering_addresses {
      ip_configuration_name = "vpnconfig"
      apipa_addresses       = [var.azure_bgp_ip]
    }
  }
}
resource "azurerm_local_network_gateway" "cisco" {
  name                = "${var.name_prefix}-cisco-lng"
  resource_group_name = var.resource_group_name
  location            = var.location
  gateway_address     = var.onprem_public_ip
  address_space       = [var.onprem_lan_cidr]
  tags                = var.tags
  bgp_settings {
    asn                 = var.onprem_bgp_asn
    bgp_peering_address = var.onprem_bgp_ip
  }
}
resource "azurerm_virtual_network_gateway_connection" "cisco" {
  name                               = "${var.name_prefix}-cisco-s2s"
  resource_group_name                = var.resource_group_name
  location                           = var.location
  type                               = "IPsec"
  virtual_network_gateway_id         = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id           = azurerm_local_network_gateway.cisco.id
  connection_protocol                = "IKEv2"
  enable_bgp                         = true
  use_policy_based_traffic_selectors = false
  shared_key                         = var.vpn_shared_key # Sensitive, but necessarily recorded in state.
  tags                               = var.tags
  ipsec_policy {
    dh_group         = "DHGroup14"
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "PFS14"
    sa_lifetime      = 27000
    sa_datasize      = 102400000
  }
}

resource "azurerm_virtual_network_peering" "hub_to" {
  for_each                     = { prod = azurerm_virtual_network.prod.id, nonprod = azurerm_virtual_network.nonprod.id }
  name                         = "hub-to-${each.key}"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = each.value
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  # VPN gateway must exist before a peering advertises gateway transit.
  depends_on = [azurerm_virtual_network_gateway.vpn]
}
resource "azurerm_virtual_network_peering" "to_hub" {
  for_each                     = { prod = azurerm_virtual_network.prod.name, nonprod = azurerm_virtual_network.nonprod.name }
  name                         = "${each.key}-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = each.value
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true
  depends_on                   = [azurerm_virtual_network_peering.hub_to]
}

resource "azurerm_public_ip" "firewall" {
  name                = "${var.name_prefix}-fw-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}
resource "azurerm_firewall_policy" "this" {
  name                     = "${var.name_prefix}-fw-policy"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  sku                      = "Standard"
  threat_intelligence_mode = "Alert"
  tags                     = var.tags
}
resource "azurerm_firewall" "this" {
  name                = "${var.name_prefix}-firewall"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.this.id
  tags                = var.tags
  ip_configuration {
    name                 = "firewall-ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}
resource "azurerm_firewall_policy_rule_collection_group" "this" {
  name               = "hybrid-security"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 100

  network_rule_collection {
    name     = "allow-private-segments"
    priority = 100
    action   = "Allow"
    rule {
      name                  = "spoke-to-spoke-tcp"
      protocols             = ["TCP"]
      source_addresses      = [var.prod_cidr, var.nonprod_cidr]
      destination_addresses = [var.prod_cidr, var.nonprod_cidr]
      destination_ports     = ["443", "8080"]
    }
    rule {
      name                  = "onprem-to-azure-test"
      protocols             = ["TCP"]
      source_addresses      = [var.onprem_lan_cidr]
      destination_addresses = [var.nonprod_vm_subnet_cidr, var.prod_pe_subnet_cidr]
      destination_ports     = ["443", "8080"]
    }
    rule {
      name                  = "azure-to-onprem-test"
      protocols             = ["TCP"]
      source_addresses      = [var.prod_cidr, var.nonprod_cidr]
      destination_addresses = [var.onprem_lan_cidr]
      destination_ports     = ["443", "8080"]
    }
  }
  application_rule_collection {
    name     = "approved-aks-egress"
    priority = 200
    action   = "Allow"
    rule {
      name                  = "aks-managed-dependencies"
      source_addresses      = [var.prod_aks_subnet_cidr]
      destination_fqdn_tags = ["AzureKubernetesService"]
      protocols {
        type = "Https"
        port = 443
      }
    }
    rule {
      name              = "aks-platform-dependencies"
      source_addresses  = [var.prod_aks_subnet_cidr]
      destination_fqdns = var.allowed_egress_fqdns
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
    }
  }
  # Implicit deny: no general outbound 80/443 network allow.
}

resource "azurerm_route_table" "spoke" {
  for_each                      = { prod = azurerm_virtual_network.prod.id, nonprod = azurerm_virtual_network.nonprod.id }
  name                          = "${var.name_prefix}-${each.key}-udr"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  disable_bgp_route_propagation = true # Inspect on-prem routes, don't bypass the firewall.
  tags                          = var.tags
}
resource "azurerm_route" "spoke_default" {
  for_each               = azurerm_route_table.spoke
  name                   = "default-via-firewall"
  resource_group_name    = var.resource_group_name
  route_table_name       = each.value.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.this.ip_configuration[0].private_ip_address
}
resource "azurerm_route" "spoke_onprem" {
  for_each               = azurerm_route_table.spoke
  name                   = "onprem-via-firewall"
  resource_group_name    = var.resource_group_name
  route_table_name       = each.value.name
  address_prefix         = var.onprem_lan_cidr
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.this.ip_configuration[0].private_ip_address
}
resource "azurerm_route_table" "gateway" {
  name                = "${var.name_prefix}-gateway-udr"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}
resource "azurerm_route" "gateway_to_spoke" {
  for_each               = { prod = var.prod_cidr, nonprod = var.nonprod_cidr }
  name                   = "${each.key}-via-firewall"
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.gateway.name
  address_prefix         = each.value
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.this.ip_configuration[0].private_ip_address
}
resource "azurerm_subnet_route_table_association" "gateway" {
  subnet_id      = azurerm_subnet.gateway.id
  route_table_id = azurerm_route_table.gateway.id
  depends_on     = [azurerm_route.gateway_to_spoke]
}
resource "azurerm_subnet_route_table_association" "prod_aks" {
  subnet_id      = azurerm_subnet.prod_aks.id
  route_table_id = azurerm_route_table.spoke["prod"].id
  depends_on     = [azurerm_route.spoke_default, azurerm_route.spoke_onprem]
}
resource "azurerm_subnet_route_table_association" "prod_pe" {
  subnet_id      = azurerm_subnet.prod_pe.id
  route_table_id = azurerm_route_table.spoke["prod"].id
  depends_on     = [azurerm_route.spoke_default, azurerm_route.spoke_onprem]
}
resource "azurerm_subnet_route_table_association" "nonprod_app" {
  subnet_id      = azurerm_subnet.nonprod_app.id
  route_table_id = azurerm_route_table.spoke["nonprod"].id
  depends_on     = [azurerm_route.spoke_default, azurerm_route.spoke_onprem]
}
resource "azurerm_subnet_route_table_association" "nonprod_pe" {
  subnet_id      = azurerm_subnet.nonprod_pe.id
  route_table_id = azurerm_route_table.spoke["nonprod"].id
  depends_on     = [azurerm_route.spoke_default, azurerm_route.spoke_onprem]
}
resource "azurerm_subnet_route_table_association" "nonprod_vm" {
  subnet_id      = azurerm_subnet.nonprod_vm.id
  route_table_id = azurerm_route_table.spoke["nonprod"].id
  depends_on     = [azurerm_route.spoke_default, azurerm_route.spoke_onprem]
}
