# Azure 클라우드 데이터 및 App 보안 구축

WordPress + Azure MySQL Flexible Server 환경에 내부자 위협(Insider Threat) 시나리오를 적용해, DB 패스워드 없는 인증과 최소 권한 접근 통제를 Terraform으로 자동 구성한 프로젝트입니다.

---

## 기술 스택

- **IaC**: Terraform (azurerm 4.74.0)
- **Cloud**: Microsoft Azure
- **DB**: Azure MySQL Flexible Server (Entra ID 전용 인증)
- **네트워크**: VNet, Azure Firewall, Application Gateway(WAF), Bastion, NSG, UDR
- **보안**: Azure Key Vault, Managed Identity, RBAC, Entra ID SSH 로그인

---

## 인프라 구성

```
├── 00_bootstrap.sh              # Key Vault / Storage Account 초기 세팅
├── 100_run.sh                   # 전체 배포 스크립트
├── 20_register_db_users.sh      # MySQL AAD 계정 자동 등록
├── install.sh.tpl               # Web VM 초기화 (WordPress, az-cli, iptables)
├── 00_init.tf ~ 08_appgw_waf.tf # VNet, NSG, NAT GW, Bastion, App Gateway/WAF
├── 09_web_vm.tf                 # Web VM + Entra ID SSH 로그인 확장
├── 10_keyvault.tf / 12_storage.tf  # Key Vault / Storage Account
├── 11_mysql.tf                  # MySQL Flexible Server, Entra ID 인증
├── 14_firewall.tf               # Azure Firewall FQDN 화이트리스트
├── 15_log.tf                    # Log Analytics, 진단 설정
├── 16_route.tf / 17_dns.tf      # UDR 강제 경유, Firewall DNS Proxy
├── 18_iam.tf                    # RBAC 역할 할당 (팀원 / 테스트 계정)
└── terraform.tfvars             # 실제 배포 값 (직접 채워야 함)
```

---

## 실행 방법

`terraform.tfvars`에 구독 ID, MySQL Entra ID 관리자, 팀원/테스트 계정 Object ID를 채운 뒤 실행합니다.

```bash
# 1. terraform.tfvars 작성 (subid, aad_admin_login, extra_db_users, team_admins, test_personas 등)

# 2. 전체 배포 (bootstrap → Terraform → MySQL 계정 등록 순서로 자동 실행)
bash 100_run.sh
```

> 리소스 이름 재사용 등으로 일부 리소스가 이미 존재해 충돌이 나면, `terraform apply`가 자동으로 감지해 import 후 재시도합니다.

---

## 최소 권한 검증 (Insider Threat 시나리오)

퇴사자 등 오프보딩이 누락된 계정을 가정해, 실제 권한 범위를 검증합니다.

- 리소스그룹 `Reader` + VM `User Login`만 부여된 계정으로 Bastion 접속
- `sudo su` → 관리자 재인증 요구로 차단
- VM Managed Identity 토큰(IMDS) 탈취 시도 → iptables로 차단
- MySQL 접속은 되지만 `GRANT OPTION` 없는 CRUD 권한으로 한정

```bash
# 검증용 테스트 계정은 terraform.tfvars의 test_personas에 등록
# → RBAC(RG Reader + VM User Login) + MySQL 계정이 자동 반영됨
```

---

## 주요 보안 구성

- **MySQL Entra ID 전용 인증**: `aad_auth_only=ON`으로 패스워드 인증 완전 차단
- **Azure Firewall FQDN 화이트리스트**: Web VM 아웃바운드를 필요한 도메인만 허용
- **Bastion + Entra ID SSH 로그인**: 공유 SSH 키 대신 개인별 Entra ID 계정으로 접속
- **RBAC 최소 권한**: 관리자(Administrator Login) / 일반 팀원(User Login) 역할 분리
- **IMDS 접근 통제**: iptables로 VM Managed Identity 토큰을 `www-data`/`root`로만 제한
- **Key Vault**: 시크릿 중앙 관리, Managed Identity로 최소 권한(`Get`/`List`) 접근
