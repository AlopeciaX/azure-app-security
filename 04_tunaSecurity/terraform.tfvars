# ============================================
# tuna-security 인프라 변수
# 이 파일은 .gitignore에 추가할 것 (민감 정보 포함)
# ============================================

subid  = "c1107cb7-a5bf-41a6-ac63-d904967901e7"
rgname = "team604tuna"
loca1  = "KoreaCentral"

size      = "Standard_D2s_v3"
publisher = "Canonical"
offer     = "0001-com-ubuntu-server-focal"
sku       = "20_04-lts-gen2"
ver       = "latest"

admin_user = "azureuser"

key_vault_name = "tuna4-keyvault-604"

# MySQL Entra ID 관리자 (student618)
aad_admin_login     = "student618_mscsschool.onmicrosoft.com#EXT#@sim981naver.onmicrosoft.com"
aad_admin_object_id = "4e0a6ec9-65d1-4d4c-9e33-ce0382ead0c2"

# ── MySQL 계정 등록 (18_iam.tf와 무관, DB 앱 계정 전용) ──
extra_db_users = {
  student612 = {
    login     = "student612"
    object_id = "538cff22-afa4-477f-a9d4-2fb598e05d02"
  }
  former_employee = {
    login     = "former-employee"
    object_id = "5ba6c831-9799-45a9-9124-a92e44dcaba0"
  }
}

# ── IAM: 팀원 (VM 스코프, Administrator Login) ──
team_admins = {
  student618 = {
    login     = "student618"
    object_id = "4e0a6ec9-65d1-4d4c-9e33-ce0382ead0c2"
  }
  student612 = {
    login     = "student612"
    object_id = "538cff22-afa4-477f-a9d4-2fb598e05d02"
  }
  student602 = { # 김령오
    login     = "student602"
    object_id = "6af97557-7cfe-4668-9aa9-8086f991addc"
  }
  student614 = { # student614(심혜원)
    login     = "student614"
    object_id = "71760992-da88-492c-9c56-978cf7b7b0a1"
  }
  student619 = { # 전건호
    login     = "student619"
    object_id = "6dbb1ac6-1048-4990-b7c3-47caa401d3f7"
  }
}

# ── IAM: 테스트 페르소나 (RG 스코프, Reader + User Login) ──
test_personas = {
  former_employee = {
    login     = "former-employee"
    object_id = "5ba6c831-9799-45a9-9124-a92e44dcaba0"
  }
}
