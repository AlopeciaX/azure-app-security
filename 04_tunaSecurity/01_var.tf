# ============================================
# 변수 정의
# 기본 설정 / VM / Key Vault / 태그
# ============================================

# 기본 설정
variable "subid" {
  type      = string
  sensitive = true
}

variable "rgname" {
  type    = string
  default = "team604tuna"
}

variable "loca1" {
  type    = string
  default = "KoreaCentral"
}

# VM 설정
variable "size" {
  type    = string
  default = "Standard_B2s"
}

variable "publisher" {
  type    = string
  default = "Canonical"
}

variable "offer" {
  type    = string
  default = "0001-com-ubuntu-server-focal"
}

variable "sku" {
  type    = string
  default = "20_04-lts-gen2"
}

variable "ver" {
  type    = string
  default = "latest"
}

variable "admin_user" {
  type    = string
  default = "azureuser"
}

# Key Vault
variable "infra_rgname" {
  type    = string
  default = "team604tuna-infra"
}

variable "key_vault_name" {
  type = string
}

variable "db_name_secret_name" {
  type    = string
  default = "db-name"
}

variable "db_user_secret_name" {
  type    = string
  default = "db-user"
}

variable "db_password_secret_name" {
  type    = string
  default = "db-password"
}

# MySQL Entra ID 관리자 (하드코딩 대신 tfvars로 분리 - gitignore 대상)
variable "aad_admin_login" {
  type      = string
  sensitive = true
}

variable "aad_admin_object_id" {
  type      = string
  sensitive = true
}

# MySQL AAD 일반 사용자 등록 전용 (login은 for_each 키로 쓰이므로 sensitive 금지)
variable "extra_db_users" {
  description = "MySQL에 AAD 일반 사용자로 등록할 계정 (팀원 + 테스트 페르소나)"
  type = map(object({
    login     = string
    object_id = string
  }))
  default = {}
}

# ── VM/Bastion IAM 관리 (18_iam.tf에서 사용) ──────────────
# 팀원: 이미 구독 Owner. VM 개별 리소스에 Administrator Login만 부여
# (Reader는 Owner가 이미 포함하므로 생략 - 확인된 사실: Owner라도 이 Login role이
#  명시적으로 없으면 Bastion 연결화면에 Microsoft Entra ID 옵션이 안 뜬다)
variable "team_admins" {
  description = "이미 구독 Owner인 실제 팀원 - VM Administrator Login만 부여"
  type = map(object({
    login     = string
    object_id = string
  }))
  default = {}
}

# 테스트 페르소나(퇴사자 등): Owner가 아니므로 리소스그룹 스코프로
# Reader + Virtual Machine User Login 부여 (sudo 불가, 최소 권한 검증 대상).
# RG 스코프라 앞으로 VM이 늘어나도 별도 코드 추가 없이 자동 적용됨.
variable "test_personas" {
  description = "Owner가 아닌 테스트 계정 - RG 스코프 Reader + VM User Login 부여"
  type = map(object({
    login     = string
    object_id = string
  }))
  default = {}
}

# 태그
variable "tags" {
  type = map(string)
  default = {
    project     = "tuna-security"
    environment = "dev"
    team        = "team604tuna"
    scenario    = "insider-threat"
  }
}

# 공유 SSH 키(azureuser) 잠금 여부 - AAD 로그인 확인 후 true로 전환 (VM 재생성 발생)
variable "lock_shared_ssh_key" {
  type    = bool
  default = false
}
