# ============================================
# Output
# ============================================

output "appgw_public_ip" {
  value       = azurerm_public_ip.appgw_pip.ip_address
  description = "WAF + App Gateway 공인 IP"
}

output "bastion_public_ip" {
  value       = azurerm_public_ip.bastion_pip.ip_address
  description = "Bastion 공인 IP"
}

output "web_vm_private_ip" {
  value       = azurerm_network_interface.web_nic.private_ip_address
  description = "Web VM 내부 IP"
}

output "mysql_fqdn" {
  value       = azurerm_mysql_flexible_server.tuna_mysql.fqdn
  description = "MySQL 접속 주소 (내부망에서만 접근 가능)"
}

output "firewall_public_ip" {
  value       = azurerm_public_ip.fw_pip.ip_address
  description = "Azure Firewall 공인 IP (아웃바운드 단일 출구)"
}

output "firewall_private_ip" {
  value       = azurerm_firewall.tuna_fw.ip_configuration[0].private_ip_address
  description = "Azure Firewall 사설 IP (UDR next-hop)"
}

output "storage_account_name" {
  value       = data.azurerm_storage_account.tuna_infra_storage.name
  description = "Storage Account 이름 (tuna-infra)"
}
