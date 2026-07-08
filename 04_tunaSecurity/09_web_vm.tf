# ============================================
# Web 서버 VM
# Ubuntu 20.04 / SSH 키: id_rsa.pub
# Custom_data로 Wordpress 자동 설치
# ============================================

# Web VM NIC
resource "azurerm_network_interface" "web_nic" {
  name                = "tuna-web-nic"
  location            = var.loca1
  resource_group_name = var.rgname
  tags                = var.tags

  ip_configuration {
    name                          = "web-ip-config"
    subnet_id                     = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_subnet.web_subnet]
}

# Web VM
resource "azurerm_linux_virtual_machine" "web_vm" {
  name                = "tuna-web-vm"
  location            = var.loca1
  resource_group_name = var.rgname
  size                = var.size
  admin_username      = var.admin_user
  tags                = var.tags

  network_interface_ids = [azurerm_network_interface.web_nic.id]

  admin_ssh_key {
    username   = var.admin_user
    public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.publisher
    offer     = var.offer
    sku       = var.sku
    version   = var.ver
  }

  # Managed Identity (Key Vault 접근용)
  identity {
    type = "SystemAssigned"
  }

  # VM 생성 시 자동 설치 스크립트
  custom_data = base64encode(templatefile("${path.module}/install.sh.tpl", {
    db_host             = azurerm_mysql_flexible_server.tuna_mysql.fqdn
    key_vault_name      = var.key_vault_name
    db_name_secret_name = var.db_name_secret_name
    lock_shared_ssh_key = var.lock_shared_ssh_key
    admin_user          = var.admin_user
  }))

  depends_on = [
    azurerm_network_interface.web_nic,
    azurerm_mysql_flexible_server.tuna_mysql
  ]
}

# App Gateway 백엔드 풀에 Web VM 연결
resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "web_appgw_assoc" {
  network_interface_id    = azurerm_network_interface.web_nic.id
  ip_configuration_name   = "web-ip-config"
  backend_address_pool_id = tolist(azurerm_application_gateway.tuna_appgw.backend_address_pool)[0].id
}

# AAD 기반 SSH 로그인 - Bastion Standard SKU 필요
resource "azurerm_virtual_machine_extension" "aad_login" {
  name                       = "AADSSHLogin"
  virtual_machine_id         = azurerm_linux_virtual_machine.web_vm.id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADSSHLoginForLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  depends_on = [azurerm_linux_virtual_machine.web_vm]
}
