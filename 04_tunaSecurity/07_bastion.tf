# ============================================
# Azure Bastion
# Bastion으로 안전한 VM 접근
# ============================================

resource "azurerm_bastion_host" "tuna_bastion" {
  name                = "tuna-bastion"
  location            = var.loca1
  resource_group_name = var.rgname
  sku                 = "Standard" # Entra ID 로그인 + 아래 두 기능은 Standard 이상 필요
  tunneling_enabled   = true       # az network bastion tunnel 로컬 터널링
  ip_connect_enabled  = true       # 임의 사설 IP(MySQL 등)로 터널 대상 지정 허용
  tags                = var.tags

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }

  depends_on = [
    azurerm_subnet.bastion_subnet,
    azurerm_public_ip.bastion_pip
  ]
}
