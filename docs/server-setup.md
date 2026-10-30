# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины
VirtualBox 7.2, Ubuntu Server 24.04 LTS (полная установка), 2048 МБ,
2 виртуальных CPU, динамический VDI 25 ГБ. Исходный пользователь `student`.

## 2. Сетевые интерфейсы
`enp0s3`: NAT, DHCP; выход к репозиториям Ubuntu и Docker.
`enp0s8`: Host-only, DHCP, 192.168.56.101/24; хост 192.168.56.1.
В netplan у enp0s8 заданы `use-routes: false`, `use-dns: false`.
Windows hosts: `192.168.56.101 devops.local api.devops.local`.
Адрес необходимо сверять командой `ip -br address` после смены DHCP-аренды.

## 3. Правило проброса портов
NAT TCP 127.0.0.1:2222 → guest:2222. В начальном снимке guest:22;
после смены порта SSH правило изменено на guest:2222.
Конфигурация хоста `~/.ssh/config`:
```
Host devops
    HostName 127.0.0.1
    Port 2222
    User devops
    IdentityFile ~/.ssh/devops_vm
    IdentitiesOnly yes
```
Закрытый ключ остаётся на хосте; сервер получает только `.pub`.

## 4. Учётные записи
`student`: исходная установка, sudo; после настройки SSH вход запрещён AllowUsers.
`devops`: группы sudo,docker; SSH по ключу Ed25519. Пароль sudo задаётся локально,
в репозитории его нет. Для восстановления с 01-clean-install:
```
sudo useradd -m -s /bin/bash -G sudo devops
sudo passwd devops
sudo install -d -m 700 -o devops -g devops /home/devops/.ssh
sudo install -m 600 -o devops -g devops /home/student/.ssh/authorized_keys /home/devops/.ssh/authorized_keys
```

## 5. Служба SSH
`/etc/ssh/sshd_config.d/99-hardening.conf`: Port 2222, PermitRootLogin no,
PasswordAuthentication no, PubkeyAuthentication yes, KbdInteractiveAuthentication no,
PermitEmptyPasswords no, MaxAuthTries 3, LoginGraceTime 30, AllowUsers devops,
X11Forwarding no, ClientAliveInterval 300, ClientAliveCountMax 2.
Предварительно отключить PasswordAuthentication yes в cloud-init drop-in,
проверить `sudo sshd -t` и фактическое `sudo sshd -T`.
Отключить socket activation: `sudo systemctl disable --now ssh.socket`;
включить/перезапустить ssh.service. Сохранять старую сессию до проверки новой.
`sudo hostnamectl set-hostname devops-vm`;
`/etc/hosts`: `127.0.1.1 devops-vm.devops.local devops-vm`.

## 6. Межсетевой экран
```
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 2222/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw logging medium
sudo ufw enable
```
Правила включают IPv6. Не создавать шесть SSH-соединений за 30 секунд.

## 7. Снимки состояния
01-clean-install: установленная и обновлённая ОС, до devops/nginx/Docker.
02-keys-configured: пользователь devops, ключ и права .ssh.
03-ssh-hardened: отключены root/пароли, SSH на 2222.
04-nginx-https: статический HTTPS-ресурс.
05-docker-compose: работающее приложение с PostgreSQL за nginx.
06-before-kr2 и 07-kr2 создаются отдельно при контрольной работе.

## 8. Веб-сервер
Пакет nginx из Ubuntu. Ресурс `/etc/nginx/sites-available/devops-site`,
ссылка в sites-enabled; стандартная ссылка default отключена.
Файлы конфигурации приведены в `nginx/devops-site`.
`/var/www/devops-site`: devops:devops, каталоги 755, файлы 644.
Сертификат 365 дней:
```
sudo openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt \
  -subj '/CN=devops.local' -addext 'subjectAltName=DNS:devops.local'
sudo chmod 600 /etc/ssl/private/devops.key
sudo chmod 644 /etc/ssl/certs/devops.crt
```
Ключ root:root. Доставка: сначала rsync --dry-run, затем фактическая доставка
с `--chmod=D755,F644`. Перед reload всегда `sudo nginx -t`.

## 9. Контейнеризация
Docker CE установлен из официального apt-репозитория download.docker.com;
docker-ce, docker-ce-cli, containerd.io, buildx и Compose plugin.
Минимальная версия Engine 28; фактическую версию проверяет `docker version`.
`sudo usermod -aG docker devops`, затем новая сессия SSH.
Проект `~/app`, исходники в `app/`. `.env` создаётся только на сервере:
```
cd ~/app
umask 077
printf 'POSTGRES_DB=app\nPOSTGRES_USER=app\nPOSTGRES_PASSWORD=%s\nDB_HOST=db\n' "$(openssl rand -hex 16)" > .env
chmod 600 .env
docker compose up -d --build
```
Владелец devops, права 600. Никогда не выводить `docker compose config` с секретом.
PostgreSQL16-alpine, том app_db_data, pg_isready; DB порт не публикуется.
Приложение python:3.12-slim/gunicorn работает непривилегированно,
публикуется только 127.0.0.1:5000. nginx `/app/` → http://127.0.0.1:5000/,
заголовки Host/X-Real-IP/X-Forwarded-For/X-Forwarded-Proto.
Аудит: `cd ~/devops-course-2026 && scripts/audit.sh`, ожидается код 0.
Для sudo в аудите сначала выполнить `sudo -v` в интерактивной SSH-сессии.
