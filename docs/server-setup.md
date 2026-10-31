# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины
VirtualBox 7.2, Ubuntu Server 24.04 LTS (полная установка), 2048 МБ,
2 виртуальных CPU, динамический VDI 25 ГБ. Исходный пользователь `student`.
SATA использует два порта: диск и оптический привод. В параметрах ядра этого
стенда задан `module_blacklist=raid456,raid6_pq`: RAID не используется, корень — ext4.
Параметр сохранён в `/etc/default/grub` после проверки повторной загрузки.
Для совместимости с Hyper-V в этой VM отключены AVX и AVX2:
```
VBoxManage setextradata devops-vm VBoxInternal/CPUM/IsaExts/AVX 0
VBoxManage setextradata devops-vm VBoxInternal/CPUM/IsaExts/AVX2 0
```
Два CPU сохранены. Сервер загружается в multi-user.target без графического сеанса.

## 2. Сетевые интерфейсы
`enp0s3`: NAT, DHCP; выход к репозиториям Ubuntu и Docker.
`enp0s8`: Host-only, DHCP, 192.168.56.101/24; хост 192.168.56.1.
В netplan у enp0s8 заданы `use-routes: false`, `use-dns: false`.
Windows hosts: `192.168.56.101 devops.local api.devops.local`.
Адрес необходимо сверять командой `ip -br address` после смены DHCP-аренды.
За NIC 2 этой VM закреплён адрес 192.168.56.101 в DHCP VirtualBox:
`VBoxManage dhcpserver modify --interface="VirtualBox Host-Only Ethernet Adapter" --vm=devops-vm --nic=2 --fixed-address=192.168.56.101`.
MTU NAT на этом хосте — 1280. Другие сетевые интерфейсы Windows не менялись.

## 3. Правило проброса портов
NAT TCP 127.0.0.1:2222 → guest:2222. В начальном снимке guest:22;
после смены порта SSH правило изменено на guest:2222.
Конфигурация хоста `~/.ssh/config`:
```
Host devops
    HostName 192.168.56.101
    Port 2222
    User devops
    IdentityFile ~/.ssh/devops_vm
    IdentitiesOnly yes
```
Закрытый ключ остаётся на хосте; сервер получает только `.pub`.
Для управления используется Host-only; NAT-проброс оставлен как резервный путь.

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

