#!/usr/bin/env bash
#
# Bài 5 (Session 03) - Web an toàn tại /opt/my-app + logs riêng
#   - Mã nguồn: /opt/my-app/html   (owner devops:www-data)
#   - Logs:     /opt/my-app/logs   (group www-data ghi được)
#
# Cách dùng (trên máy chủ Ubuntu, quyền root):
#   chmod +x setup.sh
#   sudo ./setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="/opt/my-app"

echo "==> Cài Nginx (nếu chưa có)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq nginx curl sudo

echo "==> Đảm bảo user devops + group www-data tồn tại"
id devops >/dev/null 2>&1 || useradd -m -s /bin/bash devops
getent group www-data >/dev/null 2>&1 || groupadd www-data

echo "==> Tạo cấu trúc /opt/my-app"
mkdir -p "$APP/html" "$APP/logs"
cp "$SCRIPT_DIR/opt/my-app/html/index.html" "$APP/html/index.html"

echo "==> Phân quyền sở hữu devops:www-data"
chown -R devops:www-data "$APP"

echo "==> Phân quyền truy cập"
# Thư mục 750, tệp tin 640
find "$APP" -type d -exec chmod 750 {} \;
find "$APP" -type f -exec chmod 640 {} \;
# Riêng logs: cho group www-data quyền ghi để Nginx ghi log
chmod 775 "$APP/logs"
# /opt phải cho phép đi vào
chmod 755 /opt

echo "==> Cấu hình Nginx: my-app.conf"
cp "$SCRIPT_DIR/nginx/my-app.conf" /etc/nginx/sites-available/my-app.conf
ln -sf /etc/nginx/sites-available/my-app.conf /etc/nginx/sites-enabled/my-app.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx 2>/dev/null || service nginx restart

echo "==> Test ghi file bằng user devops (KHÔNG sudo)"
sudo -u devops bash -c "echo 'Update Test' >> $APP/html/index.html"
echo "OK - 3 dong cuoi index.html:"
tail -n 3 "$APP/html/index.html"

echo "==> Test Nginx + ghi log"
curl -s -o /dev/null -w "  HTTP status: %{http_code}\n" http://localhost/
echo "  --- /opt/my-app/logs/access.log ---"
tail -n 3 "$APP/logs/access.log" 2>/dev/null || echo "  (chua co log)"

echo "==> Trạng thái phân quyền"
ls -la "$APP"
ls -la "$APP/html"
ls -la "$APP/logs"

echo "==> Hoàn tất."
