#!/usr/bin/env bash
set -uo pipefail
PASS=0; FAIL=0
check() { local desc=$1 expected=$2 actual=$3; if [[ "$actual" == "$expected" ]]; then echo "[OK] $desc"; ((PASS++)); else echo "[FAIL] $desc expected=$expected actual=$actual"; ((FAIL++)); fi; }
echo "Configuration audit $(hostname -f) $(date -Is)"
echo '[1] SSH'
sshd=$(sudo sshd -T)
check 'Root login prohibited' no "$(awk '/^permitrootlogin /{print $2}' <<<"$sshd")"
check 'Password authentication disabled' no "$(awk '/^passwordauthentication /{print $2}' <<<"$sshd")"
check 'SSH port' 2222 "$(awk '/^port /{print $2}' <<<"$sshd")"
check 'MaxAuthTries' 3 "$(awk '/^maxauthtries /{print $2}' <<<"$sshd")"
echo '[2] Firewall'
check 'UFW active' active "$(sudo ufw status | awk '/^Status:/{print $2}')"
check 'Default incoming denied' yes "$(sudo ufw status verbose | grep -q 'Default: deny (incoming)' && echo yes || echo no)"
echo '[3] Accounts'
awk -F: '$3>=1000 && $3<65534 {printf "%s uid=%s\n",$1,$3}' /etc/passwd
echo '[4] Web server'
check 'nginx active' active "$(systemctl is-active nginx)"
check 'nginx syntax' 0 "$(sudo nginx -t >/dev/null 2>&1; echo $?)"
check 'Certificate valid for 30 days' 0 "$(openssl x509 -checkend "$(( ${CERT_MIN_DAYS:-30} * 86400 ))" -noout -in /etc/ssl/certs/devops.crt >/dev/null; echo $?)"
check 'No world-writable site files' '' "$(find /var/www/devops-site -perm -o+w -print)"
check 'TLS private key permissions' 600 "$(sudo stat -c '%a' /etc/ssl/private/devops.key)"
echo "Passed: $PASS; failed: $FAIL"
[[ $FAIL -eq 0 ]]
