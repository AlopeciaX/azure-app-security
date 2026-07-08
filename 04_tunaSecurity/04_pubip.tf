# ============================================
# Public IP
# AppGW / Bastion / NATGW
# ============================================

# AppGW PIP
resource "azurerm_public_ip" "appgw_pip" {
  name                = "tuna-appgw-pip"
  resource_group_name = var.rgname
  location            = var.loca1
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  domain_name_label   = "tuna4-appgw"
  tags                = var.tags
  depends_on          = [azurerm_resource_group.tuna_rg]
}

# Bastion PIP
resource "azurerm_public_ip" "bastion_pip" {
  name                = "tuna-bastion-pip"
  resource_group_name = var.rgname
  location            = var.loca1
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  tags                = var.tags
  depends_on          = [azurerm_resource_group.tuna_rg]
}

# Firewall PIP
resource "azurerm_public_ip" "fw_pip" {
  name                = "tuna-fw-pip"
  resource_group_name = var.rgname
  location            = var.loca1
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  tags                = var.tags
  depends_on          = [azurerm_resource_group.tuna_rg]
}

# NATGW PIP
# resource "azurerm_public_ip" "natgw_pip" {
#   name                = "tuna-natgw-pip"
#   resource_group_name = var.rgname
#   location            = var.loca1
#   allocation_method   = "Static"
#   sku                 = "Standard"
#   ip_version          = "IPv4"
#   tags                = var.tags
#   depends_on          = [azurerm_resource_group.tuna_rg]
# }
