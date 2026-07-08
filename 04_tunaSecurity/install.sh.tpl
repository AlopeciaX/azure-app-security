#!/bin/bash

DB_HOST="${db_host}"
KEYVAULT_NAME="${key_vault_name}"
DB_NAME_SECRET_NAME="${db_name_secret_name}"

for i in {1..10}; do
  apt-get update -y && break
  echo "apt-get update failed, retry $i/10..."
  sleep 30
done

apt_install_retry() {
  for i in {1..10}; do
    apt-get install -y "$@" && return 0
    echo "apt-get install failed (lock/부팅 초기 충돌 가능성), retry $i/10..."
    sleep 15
  done
  echo "apt-get install 최종 실패: $*"
  return 1
}

apt_install_retry apache2 php php-mysql php-curl php-gd php-mbstring php-xml wget tar libapache2-mod-php python3 curl default-mysql-client

# az-cli 설치 (관리자/디버깅용) - curl|bash 대신 Microsoft 저장소를 명시적으로 등록
mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/keyrings/microsoft.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" \
  | tee /etc/apt/sources.list.d/azure-cli.list

for i in {1..10}; do
  apt-get update -y && break
  sleep 15
done
apt_install_retry azure-cli

ACCESS_TOKEN=$(curl -s -H Metadata:true \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net" \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

get_secret() {
  local secret_name="$1"
  curl -s \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    "https://$KEYVAULT_NAME.vault.azure.net/secrets/$secret_name?api-version=7.4" \
    | python3 -c "import sys, json; print(json.load(sys.stdin)['value'])"
}

DB_NAME=$(get_secret "$DB_NAME_SECRET_NAME")
# Entra ID 인증 전환: db-user 시크릿 대신
# MySQL AAD Admin으로 등록된 VM Managed Identity 로그인명을 직접 사용
DB_USER="tuna-web-vm"

systemctl enable --now apache2

cd /tmp
rm -rf /tmp/wordpress /tmp/wordpress-6.7.2-ko_KR.tar.gz

wget https://ko.wordpress.org/wordpress-6.7.2-ko_KR.tar.gz
tar xzf wordpress-6.7.2-ko_KR.tar.gz

rm -rf /var/www/html/*
cp -a /tmp/wordpress/. /var/www/html/

cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

sed -i "s/database_name_here/$DB_NAME/g" /var/www/html/wp-config.php
sed -i "s/username_here/$DB_USER/g" /var/www/html/wp-config.php
sed -i "s/localhost/$DB_HOST/g" /var/www/html/wp-config.php

# ============================================================
# 패스워드 완전 제거 → MySQL Entra ID(AAD) 토큰 기반 인증
# Key Vault에서 db-password를 더 이상 조회하지 않음
#
# 주의: cat >> 로 파일 "끝"에 추가하면 DB_PASSWORD 정의가
# require_once ABSPATH . 'wp-settings.php'; 보다 뒤에 위치하게 되어
# wp-settings.php가 DB 접속을 시도하는 시점에 DB_PASSWORD가 아직
# 정의되지 않는 문제가 있었음. placeholder 라인 자리에 정확히
# 삽입하도록 수정.
# ============================================================
sed -i "s/password_here/placeholder_not_used/g" /var/www/html/wp-config.php

cat > /tmp/aad_db_password.php << 'PHPEOF'

// MySQL AAD 토큰: 평소엔 cron 캐시 파일 사용, 없으면 IMDS 직접 호출
function get_aad_db_token() {
  $token_file = '/var/www/.mysql_aad_token';

  if (file_exists($token_file)) {
    $cached = trim(file_get_contents($token_file));
    if ($cached !== '') {
      return $cached;
    }
  }

  $url = 'http://169.254.169.254/metadata/identity/oauth2/token'
       . '?api-version=2018-02-01'
       . '&resource=' . urlencode('https://ossrdbms-aad.database.windows.net/');

  $ch = curl_init($url);
  curl_setopt($ch, CURLOPT_HTTPHEADER, ['Metadata: true']);
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
  curl_setopt($ch, CURLOPT_TIMEOUT, 5);
  $response = curl_exec($ch);
  curl_close($ch);

  if (!$response) {
    die('Failed to get Entra ID token for MySQL');
  }

  $json = json_decode($response, true);
  if (!isset($json['access_token'])) {
    die('No access_token returned from Managed Identity endpoint');
  }

  return $json['access_token'];
}
define('DB_PASSWORD', get_aad_db_token());
PHPEOF

# placeholder 라인 "바로 뒤"에 삽입 후, placeholder 라인만 삭제
# → require_once wp-settings.php 보다 반드시 앞에 위치
sed -i "/define( *'DB_PASSWORD', *'placeholder_not_used' *);/r /tmp/aad_db_password.php" /var/www/html/wp-config.php
sed -i "/define( *'DB_PASSWORD', *'placeholder_not_used' *);/d" /var/www/html/wp-config.php

rm -f /tmp/aad_db_password.php

sed -i "/DB_HOST/a define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);" /var/www/html/wp-config.php

# ============================================================
# MySQL AAD 토큰 발급 + 50분마다 자동 갱신 (cron)
# 토큰 유효기간 약 1시간 → 만료 전 미리 갱신
# ============================================================
cat > /usr/local/bin/refresh-mysql-token.sh << 'TOKENEOF'
#!/bin/bash
TOKEN=$(curl -s -H Metadata:true \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://ossrdbms-aad.database.windows.net" \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")
echo "$TOKEN" > /var/www/.mysql_aad_token
chown www-data:www-data /var/www/.mysql_aad_token
chmod 600 /var/www/.mysql_aad_token
TOKENEOF

chmod +x /usr/local/bin/refresh-mysql-token.sh
/usr/local/bin/refresh-mysql-token.sh

(crontab -l 2>/dev/null; echo "*/50 * * * * /usr/local/bin/refresh-mysql-token.sh") | crontab -

# IMDS 접근 제한: WordPress(www-data)/root 외 계정의 토큰 도용 방지
# ⚠️ root 권한이 있으면 규칙을 지울 수 있어 AAD 로그인 정책과 함께 적용해야 함
iptables -A OUTPUT -d 169.254.169.254 -m owner --uid-owner www-data -j ACCEPT
iptables -A OUTPUT -d 169.254.169.254 -m owner --uid-owner root -j ACCEPT
iptables -A OUTPUT -d 169.254.169.254 -j DROP

DEBIAN_FRONTEND=noninteractive apt_install_retry iptables-persistent
netfilter-persistent save

a2enmod rewrite

%{ if lock_shared_ssh_key }
# 공유 SSH 키 잠금 - AAD 확장 설치 성공을 확인한 뒤에만 실행 (락아웃 방지, 최대 5분 대기)
AAD_EXT_OK=0
for i in {1..30}; do
  if grep -rl '"status":"success"' /var/lib/waagent/Microsoft.Azure.ActiveDirectory.AADSSHLoginForLinux-*/status/*.status 2>/dev/null | grep -q .; then
    AAD_EXT_OK=1
    break
  fi
  sleep 10
done

if [ "$AAD_EXT_OK" = "1" ]; then
  passwd -l ${admin_user}
  truncate -s 0 /home/${admin_user}/.ssh/authorized_keys
  echo "AAD SSH 로그인 확인됨 - 공유 SSH 키 잠금 완료"
else
  echo "경고: AAD 확장 설치를 확인하지 못해 잠금을 건너뜁니다. 수동 확인 필요."
fi
%{ endif }

cat > /etc/apache2/conf-available/logformat-xforwarded.conf << 'APACHEEOF'
LogFormat "%%{X-Forwarded-For}i %h %l %u %t \"%r\" %>s %O %%{Referer}i %%{User-Agent}i" appgw_combined
CustomLog $${APACHE_LOG_DIR}/access.log appgw_combined
APACHEEOF

a2enconf logformat-xforwarded

cat > /etc/apache2/conf-available/wordpress-override.conf << 'APACHEEOF'
<Directory /var/www/html/>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
APACHEEOF

a2enconf wordpress-override

cat > /var/www/html/.htaccess << 'APACHEEOF'
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule .* - [E=HTTP_AUTHORIZATION:%%{HTTP:Authorization}]
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %%{REQUEST_FILENAME} !-f
RewriteCond %%{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
APACHEEOF

chown -R www-data:www-data /var/www/html/
chmod -R 755 /var/www/html/

echo "healthy" > /var/www/html/health.html

systemctl restart apache2

echo "TUNA WordPress deployment completed (Entra ID DB auth only, no password)"

# ============================================
# 웹쉘 업로드 취약점 테스트 (Before 시연용)
# ============================================

mkdir -p /var/www/html/uploads
chmod 777 /var/www/html/uploads

# 파일 업로드 페이지
cat > /var/www/html/upload.php << 'PHPEOF'
<?php
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['file'])) {
    $target = 'uploads/' . basename($_FILES['file']['name']);
    if (move_uploaded_file($_FILES['file']['tmp_name'], $target)) {
        echo "업로드 성공: " . basename($_FILES['file']['name']);
    } else {
        echo "업로드 실패";
    }
}
?>
<!DOCTYPE html>
<html>
<body>
<form method="POST" enctype="multipart/form-data">
    <input type="file" name="file">
    <input type="submit" value="업로드">
</form>
</body>
</html>
PHPEOF

# uploads .htaccess - WordPress RewriteEngine 끄고 PHP 실행 허용 (Before 상태)
cat > /var/www/html/uploads/.htaccess << 'HTEOF'
RewriteEngine Off
Options +ExecCGI
AddType application/x-httpd-php .php
HTEOF

# ============================================
# SSRF 취약점 테스트 페이지 (Before 시연용)
# ============================================
cat > /var/www/html/ssrf.php << 'PHPEOF'
<?php
$url = $_GET['url'];
$response = file_get_contents($url);
echo $response;
?>
PHPEOF

# ============================================
# 웹쉘 방어 설정 After
# uploads 폴더 PHP 실행 엔진 OFF (Apache 전역 설정)
# ============================================
cat > /etc/apache2/conf-available/no-php-uploads.conf << 'APACHEEOF'
<Directory /var/www/html/uploads>
    php_admin_flag engine off
</Directory>
APACHEEOF

# After 시연 시 아래 두 줄 활성화
# a2enconf no-php-uploads
# systemctl reload apache2

chown -R www-data:www-data /var/www/html/uploads
chown www-data:www-data /var/www/html/upload.php /var/www/html/ssrf.php

# ============================================
# SQL Injection 취약점 테스트 페이지 (Before 시연용)
# WordPress 로그인 폼은 파라미터화된 쿼리를 쓰기 때문에
# SQLi 재현이 어려워, 별도 검색 페이지로 시연
# ⚠️ 의도적으로 취약하게 작성됨 - 프로덕션에 절대 사용 금지
# ============================================
cat > /var/www/html/search.php << 'PHPEOF'
<?php
$token_file = '/var/www/.mysql_aad_token';
$token = file_exists($token_file) ? trim(file_get_contents($token_file)) : '';

$mysqli = mysqli_init();
mysqli_real_connect(
    $mysqli, '${db_host}', 'tuna-web-vm', $token, 'tuna_db', 3306, NULL, MYSQLI_CLIENT_SSL
);

if (mysqli_connect_errno()) {
    echo "DB 연결 실패: " . mysqli_connect_error();
    exit;
}

// 데모용 테이블 최초 1회 생성 + 더미 데이터 삽입
$mysqli->query("CREATE TABLE IF NOT EXISTS search_demo_users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    login VARCHAR(50),
    email VARCHAR(100)
)");

$check = $mysqli->query("SELECT COUNT(*) as cnt FROM search_demo_users");
$row = $check->fetch_assoc();
if ($row['cnt'] == 0) {
    $mysqli->query("INSERT INTO search_demo_users (login, email) VALUES
        ('tuna', 'tuna@babo.com'),
        ('hong_gildong', 'hong@tuna.com'),
        ('kim_cheolsu', 'kim@tuna.com'),
        ('lee_younghee', 'lee@tuna.com'),
        ('park_minjun', 'park@tuna.com'),
        ('choi_suyeon', 'choi@tuna.com')");
}

// ⚠️ 의도적 SQL Injection 취약점: 입력값을 검증/이스케이프 없이 쿼리에 직접 삽입
$q = isset($_GET['q']) ? $_GET['q'] : '';
$query = "SELECT id, login, email FROM search_demo_users WHERE login = '" . $q . "'";
$result = $mysqli->query($query);

if ($result) {
    while ($r = $result->fetch_assoc()) {
        echo "ID: " . $r['id'] . " / Login: " . $r['login'] . " / Email: " . $r['email'] . "<br>\n";
    }
} else {
    echo "쿼리 오류: " . $mysqli->error;
}
?>
PHPEOF

chown www-data:www-data /var/www/html/search.php
