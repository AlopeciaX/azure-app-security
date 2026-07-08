# ============================================
# Log Analytics Workspace
# Firewall 차단/허용 로그 수집
# ============================================

resource "azurerm_log_analytics_workspace" "tuna_law" {
  name                = "tuna-law"
  location            = var.loca1
  resource_group_name = var.rgname
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 1 # 크레딧 보호용 안전장치 - 하루 1GB 초과 수집 시 자동 중단(재개는 다음날 UTC 00:00)
  tags                = var.tags

  depends_on = [azurerm_resource_group.tuna_rg]
}

# Firewall 진단 설정 → Log Analytics 연결
resource "azurerm_monitor_diagnostic_setting" "fw_diag" {
  name                       = "tuna-fw-diag"
  target_resource_id         = azurerm_firewall.tuna_fw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.tuna_law.id

  # Application Rule 로그 (FQDN 허용/차단)
  enabled_log {
    category = "AzureFirewallApplicationRule"
  }

  # Network Rule 로그 (IP:Port 허용/차단)
  enabled_log {
    category = "AzureFirewallNetworkRule"
  }

  # DNS Proxy 로그 (DNS 쿼리)
  enabled_log {
    category = "AzureFirewallDnsProxy"
  }

  enabled_metric {
    category = "AllMetrics"
  }

  depends_on = [azurerm_firewall.tuna_fw]
}

# Log Analytics ID 출력 (포털에서 쿼리할 때 필요)
output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.tuna_law.id
  description = "Log Analytics Workspace ID"
}

# MySQL 진단 설정 → 접속 시도(성공/실패) 로그 수집
resource "azurerm_monitor_diagnostic_setting" "mysql_diag" {
  name                       = "tuna-mysql-diag"
  target_resource_id         = azurerm_mysql_flexible_server.tuna_mysql.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.tuna_law.id

  # 일반 로그: 접속 시도, 쿼리, 에러 등 (로그인 성공/실패 포함)
  enabled_log {
    category = "MySqlSlowLogs"
  }

  enabled_log {
    category = "MySqlAuditLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }

  depends_on = [azurerm_mysql_flexible_server.tuna_mysql]
}

# MySQL Audit Log 활성화 (서버 파라미터 설정 필요)
resource "azurerm_mysql_flexible_server_configuration" "audit_log_enabled" {
  name                = "audit_log_enabled"
  resource_group_name = var.rgname
  server_name         = azurerm_mysql_flexible_server.tuna_mysql.name
  value               = "ON"

  depends_on = [azurerm_mysql_flexible_server.tuna_mysql]
}

# Audit Log 이벤트 범위: 연결(CONNECTION) 시도 포함
resource "azurerm_mysql_flexible_server_configuration" "audit_log_events" {
  name                = "audit_log_events"
  resource_group_name = var.rgname
  server_name         = azurerm_mysql_flexible_server.tuna_mysql.name
  value               = "CONNECTION,DDL,DML"

  depends_on = [azurerm_mysql_flexible_server_configuration.audit_log_enabled]
}

# 구독 Activity Log → Log Analytics 연결
# RBAC 변경, 리소스 생성/삭제 등 관리 작업 탐지에 필요
resource "azurerm_monitor_diagnostic_setting" "subscription_activity_diag" {
  name                       = "tuna-activity-diag"
  target_resource_id         = "/subscriptions/${var.subid}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.tuna_law.id

  enabled_log {
    category = "Administrative"
  }

  enabled_log {
    category = "Security"
  }

  depends_on = [azurerm_log_analytics_workspace.tuna_law]
}

# WAF(Application Gateway) 진단 설정 → Log Analytics 연결
# 4번째 프로젝트(App 보안 설계)에서 만든 WAF 정책의 차단 로그를
# 이번 프로젝트(탐지·대응)의 Sentinel 파이프라인에 연결
resource "azurerm_monitor_diagnostic_setting" "waf_diag" {
  name                       = "tuna-waf-diag"
  target_resource_id         = azurerm_application_gateway.tuna_appgw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.tuna_law.id

  # WAF 탐지/차단 로그 (SQLi, XSS 등 OWASP 룰셋 매치 기록)
  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  # 접근 로그 (요청/응답 기본 정보)
  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_metric {
    category = "AllMetrics"
  }

  depends_on = [azurerm_application_gateway.tuna_appgw]
}
