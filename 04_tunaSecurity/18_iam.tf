# ============================================
# IAM (RBAC 역할 할당) 전용 파일
# "무엇을 만들지"(리소스)와 "누가 접근 가능한지"(권한)를 분리 관리
# ============================================

# ── 팀원 (이미 구독 Owner) ──────────────────────────
# 리소스그룹 스코프로 부여 - VM이 team604tuna 안에서 늘어나도 자동 커버됨.
# Owner는 구독 스코프에 이미 별도로 있으니(초대 시점 부여), 여기서는
# "VM 로그인"이라는 좁은 목적에 맞게 이 프로젝트 RG로만 한정한다.
# team604tuna-infra(Key Vault 등)에는 VM 자체가 없어 여기 포함 안 해도 무방.
resource "azurerm_role_assignment" "team_vm_admin_login" {
  for_each             = var.team_admins
  scope                = azurerm_resource_group.tuna_rg.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = each.value.object_id

  depends_on = [azurerm_resource_group.tuna_rg]
}

# ── 테스트 페르소나 (퇴사자 등, Owner 아님) ────────────────
# 리소스그룹 스코프로 부여 - VM이 앞으로 늘어나도 코드 수정 없이 자동 커버됨.
resource "azurerm_role_assignment" "test_persona_rg_reader" {
  for_each             = var.test_personas
  scope                = azurerm_resource_group.tuna_rg.id
  role_definition_name = "Reader"
  principal_id         = each.value.object_id

  depends_on = [azurerm_resource_group.tuna_rg]
}

resource "azurerm_role_assignment" "test_persona_vm_user_login" {
  for_each             = var.test_personas
  scope                = azurerm_resource_group.tuna_rg.id
  role_definition_name = "Virtual Machine User Login" # sudo 불가
  principal_id         = each.value.object_id

  depends_on = [azurerm_resource_group.tuna_rg]
}
