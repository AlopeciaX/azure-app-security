# ============================================
# VNet + 서브넷
# WAF / Web / Bastion / DB 서브넷
# ============================================

resource "azurerm_virtual_network" "tuna_vnet" {
  name                = "tuna-vnet"
  address_space       = ["10.101.0.0/16"]
  location            = var.loca1
  resource_group_name = var.rgname
  tags                = var.tags
  depends_on          = [azurerm_resource_group.tuna_rg]
}

# WAF 서브넷 (10.101.0.0/24)
resource "azurerm_subnet" "appgw_subnet" {
  name                 = "appgw-subnet"
  virtual_network_name = azurerm_virtual_network.tuna_vnet.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.101.0.0/24"]
  depends_on           = [azurerm_virtual_network.tuna_vnet]
}

# Web 서브넷 (10.101.1.0/24)
resource "azurerm_subnet" "web_subnet" {
  name                 = "web-subnet"
  virtual_network_name = azurerm_virtual_network.tuna_vnet.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.101.1.0/24"]
  depends_on           = [azurerm_virtual_network.tuna_vnet]
}

# Bastion 서브넷 (10.101.3.0/26)
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  virtual_network_name = azurerm_virtual_network.tuna_vnet.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.101.3.0/26"]
  depends_on           = [azurerm_virtual_network.tuna_vnet]
}

# DB 서브넷 (10.101.4.0/24)
resource "azurerm_subnet" "db_subnet" {
  name                 = "db-subnet"
  virtual_network_name = azurerm_virtual_network.tuna_vnet.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.101.4.0/24"]
  depends_on           = [azurerm_virtual_network.tuna_vnet]

  delegation {
    name = "mysql-flexible-server-delegation"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# Firewall 서브넷 (10.101.5.0/24)
resource "azurerm_subnet" "fw_subnet" {
  name                 = "AzureFirewallSubnet"
  virtual_network_name = azurerm_virtual_network.tuna_vnet.name
  resource_group_name  = var.rgname
  address_prefixes     = ["10.101.5.0/24"]
  depends_on           = [azurerm_virtual_network.tuna_vnet]
}
