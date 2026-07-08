# ============================================
# VNet DNS → Azure Firewall IP
# Firewall DNS Proxy가 모든 쿼리를 가로챔
# 외부 DNS(8.8.8.8 등) 직접 사용 차단
# ============================================

resource "null_resource" "vnet_dns_to_firewall" {
  triggers = {
    fw_private_ip = azurerm_firewall.tuna_fw.ip_configuration[0].private_ip_address
    rgname        = var.rgname
  }

  # Firewall 생성 후 VNet DNS를 FW 사설 IP로 설정
  provisioner "local-exec" {
    command = "az network vnet update --name tuna-vnet --resource-group ${var.rgname} --dns-servers ${azurerm_firewall.tuna_fw.ip_configuration[0].private_ip_address}"
  }

  # destroy 시 Azure 기본 DNS로 복원
  provisioner "local-exec" {
    when    = destroy
    command = "az network vnet update --name tuna-vnet --resource-group ${self.triggers.rgname} --dns-servers \"\""
  }

  depends_on = [azurerm_firewall.tuna_fw]
}
