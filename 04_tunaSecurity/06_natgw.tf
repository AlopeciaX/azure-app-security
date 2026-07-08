# ============================================
# NAT Gateway
# 내부 → 외부 아웃바운드 트래픽 단일 출구
# ============================================

# resource "azurerm_nat_gateway" "tuna_natgw" {
#   name                = "tuna-natgw"
#   location            = var.loca1
#   resource_group_name = var.rgname
#   sku_name            = "Standard"
#   tags                = var.tags
#   depends_on          = [azurerm_resource_group.tuna_rg]
# }

# # Nat GW ↔ PIP 연결
# resource "azurerm_nat_gateway_public_ip_association" "natgw_pip_assoc" {
#   nat_gateway_id       = azurerm_nat_gateway.tuna_natgw.id
#   public_ip_address_id = azurerm_public_ip.natgw_pip.id
# }

# # Nat GW → Web 서브넷 연결
# resource "azurerm_subnet_nat_gateway_association" "web_natgw_assoc" {
#   subnet_id      = azurerm_subnet.web_subnet.id
#   nat_gateway_id = azurerm_nat_gateway.tuna_natgw.id
# }
