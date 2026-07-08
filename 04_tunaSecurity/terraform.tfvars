# ============================================
# tuna-security 인프라 변수
# 이 파일은 .gitignore에 추가할 것 (민감 정보 포함)
# 아래는 예시 값입니다. 실제 배포 시 본인 값으로 교체하세요.
# ============================================
subid  = "00000000-0000-0000-0000-000000000000"
rgname = "team604tuna"
loca1  = "KoreaCentral"
size      = "Standard_D2s_v3"
publisher = "Canonical"
offer     = "0001-com-ubuntu-server-focal"
sku       = "20_04-lts-gen2"
ver       = "latest"
admin_user = "azureuser"
key_vault_name = "your-keyvault-name"
# MySQL Entra ID 관리자
aad_admin_login     = "admin_upn_here@yourtenant.onmicrosoft.com"
aad_admin_object_id = "00000000-0000-0000-0000-000000000000"
# ── MySQL 계정 등록 (18_iam.tf와 무관, DB 앱 계정 전용) ──
extra_db_users = {
  example_dev = {
    login     = "example-dev"
    object_id = "00000000-0000-0000-0000-000000000001"
  }
  former_employee = {
    login     = "former-employee"
    object_id = "00000000-0000-0000-0000-000000000002"
  }
}
# ── IAM: 팀원 (VM 스코프, Administrator Login) ──
team_admins = {
  admin_1 = {
    login     = "admin1"
    object_id = "00000000-0000-0000-0000-000000000000"
  }
  dev_1 = {
    login     = "dev1"
    object_id = "00000000-0000-0000-0000-000000000001"
  }
  dev_2 = { # 예시 팀원 2
    login     = "dev2"
    object_id = "00000000-0000-0000-0000-000000000003"
  }
  dev_3 = { # 예시 팀원 3
    login     = "dev3"
    object_id = "00000000-0000-0000-0000-000000000004"
  }
  dev_4 = { # 예시 팀원 4
    login     = "dev4"
    object_id = "00000000-0000-0000-0000-000000000005"
  }
}
# ── IAM: 테스트 페르소나 (RG 스코프, Reader + User Login) ──
test_personas = {
  former_employee = {
    login     = "former-employee"
    object_id = "00000000-0000-0000-0000-000000000002"
  }
}
