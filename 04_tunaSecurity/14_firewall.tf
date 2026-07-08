# ============================================
# Azure Firewall
# FQDN 기반 아웃바운드 필터링
# DNS Proxy + DNS 필터링 추가
# ============================================

resource "azurerm_firewall_policy" "tuna_fw_policy" {
  name                = "tuna-fw-policy"
  resource_group_name = var.rgname
  location            = var.loca1
  sku                 = "Standard"
  tags                = var.tags

  # DNS Proxy: 모든 DNS 쿼리를 Firewall이 가로챔
  # Azure DNS(168.63.129.16)로만 포워딩
  dns {
    proxy_enabled = true
    servers       = ["168.63.129.16"]
  }

  depends_on = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_firewall_policy_rule_collection_group" "web_rules" {
  name               = "tuna-web-rules"
  firewall_policy_id = azurerm_firewall_policy.tuna_fw_policy.id
  priority           = 100

  # ── Network 규칙: DNS 제어 ────────────────────
  # DNS 허용: Azure DNS만
  network_rule_collection {
    name     = "allow-dns"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "allow-dns-to-azure"
      protocols             = ["UDP", "TCP"]
      source_addresses      = ["10.101.0.0/16"]
      destination_addresses = ["168.63.129.16"]
      destination_ports     = ["53"]
    }
  }

  # DNS 차단: 외부 DNS (8.8.8.8, 1.1.1.1 등)
  network_rule_collection {
    name     = "deny-external-dns"
    priority = 200
    action   = "Deny"

    rule {
      name                  = "deny-all-external-dns"
      protocols             = ["UDP", "TCP"]
      source_addresses      = ["10.101.0.0/16"]
      destination_addresses = ["*"]
      destination_ports     = ["53"]
    }
  }

  # ── Application 규칙: FQDN 허용 ──────────────
  application_rule_collection {
    name     = "allow-web-outbound"
    priority = 300
    action   = "Allow"

    rule {
      name             = "allow-ubuntu-apt"
      source_addresses = ["10.101.1.0/24"]
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      destination_fqdns = [
        "archive.ubuntu.com",
        "security.ubuntu.com",
        "*.ubuntu.com",
        "*.launchpad.net",
      ]
    }

    rule {
      name             = "allow-wordpress"
      source_addresses = ["10.101.1.0/24"]
      protocols {
        type = "Https"
        port = 443
      }
      destination_fqdns = [
        "*.wordpress.org",
      ]
    }

    rule {
      name             = "allow-keyvault"
      source_addresses = ["10.101.1.0/24"]
      protocols {
        type = "Https"
        port = 443
      }
      destination_fqdns = [
        "*.vault.azure.net",
      ]
    }

    rule {
      name             = "allow-entra-id-auth"
      source_addresses = ["10.101.1.0/24"]
      protocols {
        type = "Https"
        port = 443
      }
      destination_fqdns = [
        "login.microsoftonline.com",
        "*.login.microsoftonline.com",
        "management.azure.com",
        "graph.microsoft.com", # AADSSHLoginForLinux의 PAM 계정 조회에 필요
      ]
    }

    rule {
      name             = "allow-microsoft-packages"
      source_addresses = ["10.101.1.0/24"]
      protocols {
        type = "Https"
        port = 443
      }
      destination_fqdns = [
        "packages.microsoft.com",
        "aka.ms",
        "azurecliprod.blob.core.windows.net"
      ]
    }
  }

  depends_on = [azurerm_firewall_policy.tuna_fw_policy]
}

resource "azurerm_firewall" "tuna_fw" {
  name                = "tuna-firewall"
  location            = var.loca1
  resource_group_name = var.rgname
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.tuna_fw_policy.id
  tags                = var.tags

  ip_configuration {
    name                 = "fw-ip-config"
    subnet_id            = azurerm_subnet.fw_subnet.id
    public_ip_address_id = azurerm_public_ip.fw_pip.id
  }

  depends_on = [
    azurerm_subnet.fw_subnet,
    azurerm_public_ip.fw_pip,
    azurerm_firewall_policy_rule_collection_group.web_rules,
  ]
}
