# 리소스 그룹
resource "azurerm_resource_group" "tuna_rg" {
  name     = var.rgname
  location = var.loca1
  tags     = var.tags
}
