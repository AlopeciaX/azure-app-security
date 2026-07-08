#!/bin/bash
# ============================================================
#  Bootstrap 스크립트
#  생성 리소스 (team604tuna-infra):
#    ├── Storage Account  ← tfstate 백엔드
#    └── Key Vault        ← 시크릿 저장
#
#  실행:
#    bash 100_run.sh (자동 실행됨)
#
#  검증:
#    az keyvault secret list --vault-name tuna4-keyvault-604 -o table
# ============================================================

set -e

# 설정값
LOCATION="KoreaCentral"
INFRA_RG="team604tuna-infra"
STORAGE_ACCOUNT="tuna4tfstate604"
CONTAINER_NAME="tfstate"
DB_BACKUP_CONTAINER="dbbackup"
KEY_VAULT_NAME="tuna4-keyvault-604"

# 시크릿 값
DB_NAME="tuna_db"
DB_USER="tuna"
DB_PASSWORD="${DB_PASSWORD:-It12345@}"

# 구독 확인
echo "==> 구독 설정 확인..."
az account set --subscription "$SUBSCRIPTION_ID"

TENANT_ID=$(az account show --query tenantId -o tsv)
CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null \
                  || az account show --query id -o tsv)

echo "  구독 ID  : $SUBSCRIPTION_ID"
echo "  테넌트   : $TENANT_ID"
echo "  실행 주체: $CURRENT_USER_ID"

# ── [1/6] 리소스그룹 생성 ────────────────────
echo ""
echo "── [1/6] 리소스그룹 생성"

az group create \
  --name "$INFRA_RG" \
  --location "$LOCATION" \
  --output none
echo "  ✔ $INFRA_RG"

# ── [2/6] Storage Account 생성 ───────────────
echo ""
echo "── [2/6] Storage Account 생성"

if az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$INFRA_RG" &>/dev/null; then
  echo "  ℹ️  Storage Account 이미 존재, 생성 스킵"
else
  az storage account create \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$INFRA_RG" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --https-only true \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --output none
  echo "  ✔ Storage Account: $STORAGE_ACCOUNT"
  echo "  ⏳ RBAC 전파 대기 (30초)..."
  sleep 30
fi

STORAGE_ACCOUNT_KEY=$(az storage account keys list \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$INFRA_RG" \
  --query "[0].value" -o tsv)

create_container() {
  local name="$1"
  if az storage container create \
      --name "$name" \
      --account-name "$STORAGE_ACCOUNT" \
      --auth-mode login \
      --output none 2>/dev/null; then
    echo "  ✔ Container: $name"
  else
    echo "  ⚠️  login 인증 실패, account-key 인증으로 재시도..."
    az storage container create \
      --name "$name" \
      --account-name "$STORAGE_ACCOUNT" \
      --account-key "$STORAGE_ACCOUNT_KEY" \
      --output none
    echo "  ✔ Container: $name"
  fi
}

create_container "$CONTAINER_NAME"
create_container "$DB_BACKUP_CONTAINER"
create_container "logs"

# ── [3/6] Key Vault 생성 ─────────────────────
echo ""
echo "── [3/6] Key Vault 생성"

if az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$INFRA_RG" &>/dev/null; then
  echo "  ℹ️  Key Vault 이미 존재, 생성 스킵"
else
  DELETED=$(az keyvault list-deleted --query "[?name=='$KEY_VAULT_NAME'].name" -o tsv 2>/dev/null)
  if [[ -n "$DELETED" ]]; then
    echo "  ⚠️  soft-delete 상태 감지, purge 실행..."
    az keyvault purge --name "$KEY_VAULT_NAME" --location "$LOCATION" --output none
    echo "  ✔ purge 완료"
  fi

  az keyvault create \
    --name "$KEY_VAULT_NAME" \
    --resource-group "$INFRA_RG" \
    --location "$LOCATION" \
    --sku standard \
    --enable-rbac-authorization false \
    --retention-days 7 \
    --output none
  echo "  ✔ Key Vault: $KEY_VAULT_NAME"
fi

az keyvault set-policy \
  --name "$KEY_VAULT_NAME" \
  --object-id "$CURRENT_USER_ID" \
  --secret-permissions get list set delete recover \
  --output none
echo "  ✔ 실행 주체 Access Policy 완료"

# ── [4/6] SSH 키 생성 ────────────────────────
echo ""
echo "── [4/6] SSH 키 생성"

SSH_KEY_FILE="$HOME/.ssh/id_rsa"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [[ -f "$SSH_KEY_FILE" ]]; then
  echo "  ℹ️  SSH 키 이미 존재, 기존 키 사용"
else
  ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_FILE" -N "" -q
  chmod 600 "$SSH_KEY_FILE"
  echo "  ✔ SSH 키 생성 완료 (~/.ssh/id_rsa)"
fi

# ── [5/6] 시크릿 등록 ────────────────────────
echo ""
echo "── [5/6] 시크릿 등록"

set_secret_if_absent() {
  local name="$1"
  local value="$2"
  if az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "$name" &>/dev/null; then
    echo "  ℹ️  $name 이미 존재, 스킵"
  else
    az keyvault secret set \
      --vault-name "$KEY_VAULT_NAME" \
      --name "$name" \
      --value "$value" \
      --output none
    echo "  ✔ $name"
  fi
}

set_secret_if_absent "db-name"             "$DB_NAME"
set_secret_if_absent "db-user"             "$DB_USER"
set_secret_if_absent "db-password"         "$DB_PASSWORD"
set_secret_if_absent "storage-account-key" "$STORAGE_ACCOUNT_KEY"

# ── [6/6] 팀원 Access Policy 등록 ────────────
echo ""
echo "── [6/6] 팀원 Access Policy 등록"

# 팀원 실명/Object ID는 별도 파일(team_members.env)에서 로드
# 이 파일은 .gitignore 대상이라 저장소에 커밋되지 않음
TEAM_MEMBERS_FILE="$(dirname "$0")/team_members.env"
if [[ ! -f "$TEAM_MEMBERS_FILE" ]]; then
  echo "  ⚠️  $TEAM_MEMBERS_FILE 없음, 팀원 Access Policy 등록 스킵"
else
  # shellcheck disable=SC1090
  source "$TEAM_MEMBERS_FILE"

  for NAME in "${!TEAM_MEMBERS[@]}"; do
    OID="${TEAM_MEMBERS[$NAME]}"
    az keyvault set-policy \
      --name "$KEY_VAULT_NAME" \
      --object-id "$OID" \
      --secret-permissions get list set delete recover \
      --output none
    echo "  ✔ $NAME"
  done
fi

# 완료
echo ""
echo "✅ Bootstrap 완료!"
echo ""
echo "  검증: az keyvault secret list --vault-name $KEY_VAULT_NAME -o table"
echo "  다음: bash 100_run.sh"