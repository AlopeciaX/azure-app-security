#!/bin/bash
# ============================================================
#  전체 실행 스크립트
#  기존 하이브리드 코드 100_run.sh 기반
#  VPN, MySQL 복제, Failover 단계 제거
#
#  실행 환경: Git Bash (PowerShell, CMD 사용 불가)
#
#  실행:
#    bash 100_run.sh
# ============================================================

set -e

# Git Bash(MINGW64)에서 /subscriptions/... 같은 경로가 Windows 경로로
# 잘못 변환되는 문제 방지 (이 스크립트 안에서는 항상 안전하게 동작하도록)
export MSYS_NO_PATHCONV=1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TF_DIR="$SCRIPT_DIR"

# ────────────────────────────────────────────────────────────
#  구독 ID 설정 (메모리에만 존재)
# ────────────────────────────────────────────────────────────
export SUBSCRIPTION_ID="c1107cb7-a5bf-41a6-ac63-d904967901e7"
export TF_VAR_subid="$SUBSCRIPTION_ID"

echo "============================================"
echo "  tuna-security 인프라 배포 시작"
echo "============================================"
echo ""

# ────────────────────────────────────────────────────────────
#  사전 확인
# ────────────────────────────────────────────────────────────
if [[ ! -f "$SCRIPT_DIR/00_bootstrap.sh" ]]; then
  echo "❌ 00_bootstrap.sh 파일을 찾을 수 없습니다."
  exit 1
fi

if ! command -v terraform &>/dev/null; then
  echo "❌ terraform이 설치되어 있지 않습니다."
  exit 1
fi

if ! command -v az &>/dev/null; then
  echo "❌ az CLI가 설치되어 있지 않습니다."
  exit 1
fi

# ────────────────────────────────────────────────────────────
#  1단계: Bootstrap (Storage Account + Key Vault 생성)
# ────────────────────────────────────────────────────────────
echo "============================================"
echo "  [1단계] Bootstrap 실행"
echo "  Storage Account + Key Vault 생성"
echo "============================================"
echo ""

bash "$SCRIPT_DIR/00_bootstrap.sh"

echo ""
echo "✅ Bootstrap 완료"

# ────────────────────────────────────────────────────────────
#  2단계: Terraform
# ────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  [2단계] Terraform 실행"
echo "============================================"
echo ""

cd "$TF_DIR"
echo "  경로: $(pwd)"
echo ""

echo "── terraform init ──────────────────────────"
terraform init
echo ""

SUB="c1107cb7-a5bf-41a6-ac63-d904967901e7"
RG="team604tuna"

import_known_conflicts() {
  echo "── 기존 리소스 state 반영 시도 (실패하는 항목은 무시) ──"
  terraform import azurerm_monitor_diagnostic_setting.fw_diag \
    "/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Network/azureFirewalls/tuna-firewall|tuna-fw-diag" 2>&1 | tail -3 || true

  terraform import azurerm_monitor_diagnostic_setting.mysql_diag \
    "/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.DBforMySQL/flexibleServers/tuna4-mysql|tuna-mysql-diag" 2>&1 | tail -3 || true

  terraform import azurerm_monitor_diagnostic_setting.subscription_activity_diag \
    "/subscriptions/$SUB|tuna-activity-diag" 2>&1 | tail -3 || true

  terraform import azurerm_monitor_diagnostic_setting.waf_diag \
    "/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Network/applicationGateways/tuna4-appgw|tuna-waf-diag" 2>&1 | tail -3 || true
}

echo "── terraform apply ─────────────────────────"
set +e
terraform apply --auto-approve 2>&1 | tee /tmp/tf_apply_output.log
APPLY_EXIT=${PIPESTATUS[0]}
set -e

if [ "$APPLY_EXIT" -ne 0 ] && grep -q "already exists - to be managed via Terraform this resource needs to be imported\|RoleAssignmentExists" /tmp/tf_apply_output.log; then
  echo ""
  echo "── apply 실패: 이미 존재하는 리소스 감지 → 자동 import 후 재시도 ──"
  import_known_conflicts
  echo ""
  echo "── terraform apply (재시도) ─────────────────"
  terraform apply --auto-approve
fi

# ────────────────────────────────────────────────────────────
#  3단계: VM 생성 완료 후 MySQL AAD 사용자 자동 등록
#  로컬에 mysql 클라이언트가 없어도, Bastion 경유로 VM 안의
#  mysql 클라이언트를 원격 실행시켜 처리한다.
# ────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  [3단계] MySQL AAD 사용자 등록"
echo "============================================"
echo ""

bash "$SCRIPT_DIR/20_register_db_users.sh"

# ────────────────────────────────────────────────────────────
#  완료
# ────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  ✅ 전체 배포 완료!"
echo "============================================"
echo ""
echo "  output 확인:"
echo "  terraform output"
echo ""
echo "  App Gateway IP:"
echo "  terraform output appgw_public_ip"