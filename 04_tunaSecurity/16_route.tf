# ============================================
# Route Table (UDR)
# Web 서브넷 아웃바운드 → Azure Firewall 강제 경유
# ============================================

resource "azurerm_route_table" "web_rt" {
  name                          = "tuna-web-rt"
  location                      = var.loca1
  resource_group_name           = var.rgname
  bgp_route_propagation_enabled = false
  tags                          = var.tags

  depends_on = [azurerm_resource_group.tuna_rg]
}

# 인터넷 트래픽 → Firewall 경유
resource "azurerm_route" "default_to_fw" {
  name                   = "default-to-firewall"
  resource_group_name    = var.rgname
  route_table_name       = azurerm_route_table.web_rt.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.tuna_fw.ip_configuration[0].private_ip_address

  depends_on = [azurerm_firewall.tuna_fw]
}

# VNet 내부 트래픽 → 직접 통신 (Bastion SSH 접속 유지)
resource "azurerm_route" "vnet_local" {
  name                = "vnet-local-direct"
  resource_group_name = var.rgname
  route_table_name    = azurerm_route_table.web_rt.name
  address_prefix      = "10.101.0.0/16"
  next_hop_type       = "VnetLocal"

  depends_on = [azurerm_route_table.web_rt]
}

# Web 서브넷에 Route Table 연결
resource "azurerm_subnet_route_table_association" "web_rt_assoc" {
  subnet_id      = azurerm_subnet.web_subnet.id
  route_table_id = azurerm_route_table.web_rt.id

  depends_on = [
    azurerm_route.default_to_fw,
    azurerm_route.vnet_local,
  ]
}
