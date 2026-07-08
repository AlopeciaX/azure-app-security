# ============================================
# WAF + Application Gateway
# OWASP 3.2 / Prevention 모드
# wp-login.php, wp-admin, wp-json Allow 처리
# ============================================

resource "azurerm_web_application_firewall_policy" "appgw_waf" {
  name                = "tuna-waf-policy"
  resource_group_name = var.rgname
  location            = var.loca1
  tags                = var.tags

  policy_settings {
    enabled = true
    mode    = "Prevention"
  }

  # WordPress 경로 명시적 허용
  custom_rules {
    name      = "AllowWpPaths"
    priority  = 1
    rule_type = "MatchRule"
    action    = "Allow"

    match_conditions {
      match_variables {
        variable_name = "RequestUri"
      }
      operator     = "Contains"
      match_values = ["/wp-login.php", "/wp-admin/", "/wp-json/"]
    }
  }

  # 업로드 폴더 PHP 실행 차단 (웹쉘 방어)
  custom_rules {
    name      = "BlockUploadsPhp"
    priority  = 2
    rule_type = "MatchRule"
    action    = "Block"

    match_conditions {
      match_variables {
        variable_name = "RequestUri"
      }
      operator           = "Contains"
      negation_condition = false
      match_values       = ["/uploads/"]
    }

    match_conditions {
      match_variables {
        variable_name = "RequestUri"
      }
      operator           = "EndsWith"
      negation_condition = false
      match_values       = [".php"]
    }
  }

  managed_rules {
    exclusion {
      match_variable          = "RequestArgNames"
      selector                = "reason"
      selector_match_operator = "Equals"
    }

    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }

  depends_on = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_application_gateway" "tuna_appgw" {
  name                = "tuna4-appgw"
  resource_group_name = var.rgname
  location            = var.loca1
  firewall_policy_id  = azurerm_web_application_firewall_policy.appgw_waf.id
  tags                = var.tags

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_ip_configuration {
    name                 = "appgw-frontend"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  backend_address_pool {
    name = "web-backend-pool"
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = "health-probe"
  }

  probe {
    name                = "health-probe"
    protocol            = "Http"
    path                = "/health.html"
    host                = "127.0.0.1"
    interval            = 30
    timeout             = 20
    unhealthy_threshold = 3
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "appgw-frontend"
    frontend_port_name             = "port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "web-backend-pool"
    backend_http_settings_name = "http-settings"
    priority                   = 100
  }

  depends_on = [
    azurerm_public_ip.appgw_pip,
    azurerm_subnet.appgw_subnet,
    azurerm_web_application_firewall_policy.appgw_waf
  ]
}
