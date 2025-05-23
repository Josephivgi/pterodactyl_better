#!/bin/bash
# Pterodactyl Panel & Wings installation script for AlmaLinux 9
# DB root and pterodactyl user password: Joseph29!
# Panel IP: 77.37.121.216

set -e

DB_ROOT_PASS="Joseph29!"
DB_PASS="Joseph29!"
DB_USER="pterodactyl"
DB_NAME="panel"
PANEL_IP="77.37.121.216"

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Update system and install EPEL
dnf -y update

dnf install -y epel-release yum-utils

dnf config-manager --set-enabled crb

# Install required packages
dnf module reset -y php

dnf module enable -y php:8.1

dnf module reset -y nodejs

dnf module enable -y nodejs:18

dnf install -y nginx mariadb-server redis git unzip curl \
    php php-cli php-fpm php-gd php-mbstring php-xml php-mysqlnd \
    php-bcmath php-json php-zip php-curl php-intl php-gmp \
    composer nodejs yarn

# Install Docker
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

dnf install -y docker-ce docker-ce-cli containerd.io

systemctl enable --now docker

# Enable and start services
systemctl enable --now nginx mariadb redis php-fpm

# Secure MariaDB and create panel database
mysql -u root <<MYSQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
FLUSH PRIVILEGES;
CREATE DATABASE ${DB_NAME};
CREATE USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'127.0.0.1';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
MYSQL

# Install Pterodactyl Panel
useradd -m -d /var/www/pterodactyl -s /bin/bash pterodactyl || true
cd /var/www/pterodactyl

curl -L https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz -o panel.tar.gz

tar -xzvf panel.tar.gz

cp .env.example .env

composer install --no-dev --optimize-autoloader

php artisan key:generate --force

# Configure environment variables
sed -i "s|APP_URL=.*|APP_URL=http://${PANEL_IP}|" .env
sed -i "s|DB_HOST=.*|DB_HOST=127.0.0.1|" .env
sed -i "s|DB_PORT=.*|DB_PORT=3306|" .env
sed -i "s|DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|" .env
sed -i "s|DB_USERNAME=.*|DB_USERNAME=${DB_USER}|" .env
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" .env

php artisan migrate --seed --force

chown -R nginx:nginx /var/www/pterodactyl
chmod -R 755 storage bootstrap/cache

# Configure Pteroq service
cat >/etc/systemd/system/pteroq.service <<'SERVICE'
[Unit]
Description=Pterodactyl Queue Worker
After=redis.service

[Service]
User=nginx
Group=nginx
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,default --sleep=3 --tries=3
StartLimitInterval=180
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now pteroq.service

# Configure Nginx
cat >/etc/nginx/conf.d/pterodactyl.conf <<'NGINX'
server {
    listen 80;
    server_name ${PANEL_IP};
    root /var/www/pterodactyl/public;

    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_index index.php;
        include fastcgi.conf;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINX

systemctl reload nginx

# Install Wings
curl -L https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 -o /usr/local/bin/wings
chmod +x /usr/local/bin/wings

useradd -r -m -d /etc/pterodactyl -s /usr/sbin/nologin wings || true
mkdir -p /etc/pterodactyl /var/lib/pterodactyl

cat >/etc/systemd/system/wings.service <<'SERVICE'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service

[Service]
User=wings
Group=wings
Restart=on-failure
LimitNOFILE=4096
ExecStart=/usr/local/bin/wings

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now wings

# Firewall configuration
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=2022/tcp
firewall-cmd --permanent --add-port=25565/tcp
firewall-cmd --reload

cat <<INFO

Installation complete!
Visit: http://${PANEL_IP} to finish setup.
MariaDB Root Password: ${DB_ROOT_PASS}
Panel Database: ${DB_NAME}
Panel DB User: ${DB_USER}
Panel DB Password: ${DB_PASS}
Configure Wings by editing /etc/pterodactyl/config.yml with your node details and API credentials.
INFO
