# ============================================
# Key Vault
# 팀원 접근 정책 추가
# ============================================

data "azurerm_client_config" "current" {}

data "azurerm_key_vault" "tuna_kv" {
  name                = var.key_vault_name
  resource_group_name = var.infra_rgname
}

data "azurerm_key_vault_secret" "db_name" {
  name         = var.db_name_secret_name
  key_vault_id = data.azurerm_key_vault.tuna_kv.id
}

data "azurerm_key_vault_secret" "db_user" {
  name         = var.db_user_secret_name
  key_vault_id = data.azurerm_key_vault.tuna_kv.id
}

data "azurerm_key_vault_secret" "db_password" {
  name         = var.db_password_secret_name
  key_vault_id = data.azurerm_key_vault.tuna_kv.id
}

# Web VM Managed Identity Access Policy
resource "azurerm_key_vault_access_policy" "web_vm_policy" {
  key_vault_id = data.azurerm_key_vault.tuna_kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.web_vm.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}
