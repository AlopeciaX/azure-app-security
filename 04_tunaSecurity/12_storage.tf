# ============================================================
# Storage Account
# tuna-infra의 Storage Account(tuna4tfstate604)를 참조
# 컨테이너는 bootstrap에서 생성하므로 여기서는 참조만
# ============================================================

data "azurerm_storage_account" "tuna_infra_storage" {
  name                = "tuna4tfstate604"
  resource_group_name = "team604tuna-infra"
}
