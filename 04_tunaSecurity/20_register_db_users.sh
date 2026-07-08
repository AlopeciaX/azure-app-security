#!/bin/bash
# ============================================================
# terraform apply(VM 생성) 완료 후 실행
# az vm run-command invoke로 VM 안의 mysql 클라이언트를 원격 실행한다.
# (Azure VM Agent를 통해 바로 실행되므로 Bastion/SSH 인증이 필요 없음)
#
# 사전 조건:
#   - az login이 MySQL AAD Admin(aad_admin_login) 계정으로 되어 있을 것
#   - 이 계정에 대상 VM의 Contributor 이상 권한이 있을 것
#     (Microsoft.Compute/virtualMachines/runCommands/write)
#
# 실행: bash 20_register_db_users.sh
# ============================================================

set -e

RG="team604tuna"
VM_NAME="tuna-web-vm"
MYSQL_FQDN="tuna4-mysql.mysql.database.azure.com"
DB_NAME="tuna_db"
ADMIN_LOGIN="student618_mscsschool.onmicrosoft.com#EXT#@sim981naver.onmicrosoft.com"

# 등록할 사용자 목록: "로그인명:Object ID"
USERS=(
  "tuna-web-vm:$(az vm show --resource-group "$RG" --name "$VM_NAME" --query identity.principalId -o tsv)"
  "student612:538cff22-afa4-477f-a9d4-2fb598e05d02"
  "former-employee:5ba6c831-9799-45a9-9124-a92e44dcaba0"
)

echo "── admin 토큰 발급 ──"
TOKEN=$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)

for entry in "${USERS[@]}"; do
  LOGIN="${entry%%:*}"
  OBJECT_ID="${entry##*:}"

  echo "── $LOGIN 등록 중... ──"

  SCRIPT="mysql -h $MYSQL_FQDN -u '$ADMIN_LOGIN' --enable-cleartext-plugin --password='$TOKEN' --ssl-mode=REQUIRED -e \"SET aad_auth_validate_oids_in_tenant = OFF; CREATE AADUSER IF NOT EXISTS '$LOGIN' IDENTIFIED BY '$OBJECT_ID'; GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, CREATE TEMPORARY TABLES, LOCK TABLES ON $DB_NAME.* TO '$LOGIN'@'%'; FLUSH PRIVILEGES;\""

  az vm run-command invoke \
    --resource-group "$RG" \
    --name "$VM_NAME" \
    --command-id RunShellScript \
    --scripts "$SCRIPT" \
    --query "value[0].message" -o tsv

  echo "✔ $LOGIN 등록 완료"
  echo ""
done

echo "모든 사용자 등록 완료"
