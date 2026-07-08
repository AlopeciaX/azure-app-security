# ============================================
# MySQL Flexible Server
# Key Vault 시크릿 참조
# Entra ID 인증 추가 (패스워드 탈취 방지)
# ============================================

resource "azurerm_private_dns_zone" "mysql_dns" {
  name                = "tuna.mysql.database.azure.com"
  resource_group_name = var.rgname
  tags                = var.tags

  depends_on = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql_dns_link" {
  name                  = "tuna-mysql-dns-link"
  resource_group_name   = var.rgname
  private_dns_zone_name = azurerm_private_dns_zone.mysql_dns.name
  virtual_network_id    = azurerm_virtual_network.tuna_vnet.id
  tags                  = var.tags
}

# MySQL Entra ID 인증용 관리 ID
resource "azurerm_user_assigned_identity" "mysql_identity" {
  name                = "tuna-mysql-identity"
  location            = var.loca1
  resource_group_name = var.rgname
  tags                = var.tags

  depends_on = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_mysql_flexible_server" "tuna_mysql" {
  name                = "tuna4-mysql"
  resource_group_name = var.rgname
  location            = var.loca1

  administrator_login    = data.azurerm_key_vault_secret.db_user.value
  administrator_password = data.azurerm_key_vault_secret.db_password.value

  sku_name = "GP_Standard_D2ds_v4"
  version  = "8.0.21"

  delegated_subnet_id = azurerm_subnet.db_subnet.id
  private_dns_zone_id = azurerm_private_dns_zone.mysql_dns.id

  storage {
    size_gb           = 32
    auto_grow_enabled = true
  }

  backup_retention_days = 7
  tags                  = var.tags

  # Entra ID 인증 활성화 (패스워드 인증 + Entra 인증 동시 사용)
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.mysql_identity.id]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.mysql_dns_link,
    azurerm_resource_group.tuna_rg,
    azurerm_user_assigned_identity.mysql_identity
  ]
}

# ── DB 관리자 Entra ID 계정 지정 ─────────────────
# 관리자(Admin) 슬롯은 1개만 가능 → var.aad_admin_login 계정만 관리자로 등록
# tuna-web-vm은 관리자가 아닌 "일반 사용자"로 SQL을 통해 별도 추가 (최소권한 원칙)
resource "azurerm_mysql_flexible_server_active_directory_administrator" "mysql_aad_admin_user" {
  server_id   = azurerm_mysql_flexible_server.tuna_mysql.id
  identity_id = azurerm_user_assigned_identity.mysql_identity.id
  login       = var.aad_admin_login
  object_id   = var.aad_admin_object_id
  tenant_id   = data.azurerm_client_config.current.tenant_id

  depends_on = [azurerm_mysql_flexible_server.tuna_mysql]
}

resource "azurerm_mysql_flexible_database" "tuna_db" {
  name                = data.azurerm_key_vault_secret.db_name.value
  resource_group_name = var.rgname
  server_name         = azurerm_mysql_flexible_server.tuna_mysql.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"

  depends_on = [azurerm_mysql_flexible_server.tuna_mysql]
}

# ── 패스워드 인증 완전 차단 → Entra ID 전용 모드 ─────
# 반드시 mysql_aad_admin_user 등록 후 적용
resource "azurerm_mysql_flexible_server_configuration" "aad_auth_only" {
  name                = "aad_auth_only"
  resource_group_name = var.rgname
  server_name         = azurerm_mysql_flexible_server.tuna_mysql.name
  value               = "ON"

  depends_on = [
    azurerm_mysql_flexible_server_active_directory_administrator.mysql_aad_admin_user,
    azurerm_mysql_flexible_database.tuna_db
  ]
}

# MySQL AAD 일반 사용자(팀원, VM identity) 등록은
# terraform apply 완료 후 20_register_db_users.sh에서 처리한다.
# (로컬 PC에 mysql 클라이언트 설치 없이 Bastion 경유로 VM 안에서 실행)
