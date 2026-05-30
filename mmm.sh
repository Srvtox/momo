#!/bin/bash

# === تنظیمات ===
XRAY_BIN="/usr/local/bin/xray"        # مسیر نهایی نصب Xray core
CONFIG_FILE="/etc/xray/config.json"   # مسیر فایل کانفیگ
LOG_DIR="/var/log/xray"               # مسیر لاگ‌ها
SERVICE_NAME="xray"                   # نام سرویس systemd

# === محتوای فایل کانفیگ ===
# *** این بخش را با کانفیگ JSON که به شما دادم جایگزین کنید ***
# *** دقت کنید که کوتیشن‌ها و کاراکترهای خاص درست باشند ***
CONFIG_JSON='{
  "log": {
    "loglevel": "warning"
  },
  "routing": {
    "domainStrategy": "AsIs",
    "rules": []
  },
  "inbounds": [
    {
      "port": 8888,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "18f9720c-c68e-4a6c-940a-5c3f350c3d9a",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "sniffing": {
        "enabled": false
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/fast-game"
        },
        "sockopt": {
          "tcpFastOpen": true,
          "tcpNoDelay": true,
          "mark": 255
        }
      }
    },
    {
      "port": 8889,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "18f9720c-c68e-4a6c-940a-5c3f350c3d9a",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "sniffing": {
        "enabled": false
      },
      "streamSettings": {
        "network": "grpc",
        "security": "none",
        "grpcSettings": {
          "serviceName": "fast-game"
        },
        "sockopt": {
          "tcpFastOpen": true,
          "tcpNoDelay": true,
          "mark": 255
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIP"
      },
      "streamSettings": {
        "sockopt": {
          "tcpFastOpen": true,
          "tcpNoDelay": true
        }
      }
    }
  ],
  "policy": {
    "levels": {
      "0": {
        "handshake": 1,
        "connIdle": 60,
        "uplinkOnly": 0,
        "downlinkOnly": 0,
        "bufferSize": 2
      }
    },
    "system": {
      "statsInboundUplink": false,
      "statsInboundDownlink": false
    }
  }
}'

# === تابع برای نصب وابستگی‌ها ===
install_dependencies() {
    echo "[*] شروع نصب وابستگی‌ها..."

    # 1. آپدیت لیست پکیج‌ها
    echo "[*] مرحله 1/4: آپدیت لیست پکیج‌ها (apt update)..."
    if sudo apt update -y; then
        echo "[+] لیست پکیج‌ها با موفقیت آپدیت شد."
    else
        echo "[!] خطا در آپدیت لیست پکیج‌ها. لطفاً دستور 'sudo apt update' را دستی اجرا کنید."
        exit 1
    fi

    # 2. نصب بسته‌های مورد نیاز (wget, unzip, systemd)
    echo "[*] مرحله 2/4: نصب بسته‌های wget, unzip, systemd..."
    if sudo apt install -y wget unzip systemd; then
        echo "[+] بسته‌های wget, unzip, systemd با موفقیت نصب شدند."
    else
        echo "[!] خطا در نصب بسته‌های مورد نیاز. لطفاً دستور 'sudo apt install -y wget unzip systemd' را دستی اجرا کنید."
        exit 1
    fi

    # 3. بررسی دسترسی به network-manager (برای تنظیمات شبکه، اگر لازم باشد - فعلا استفاده نمی‌شود)
    # echo "[*] مرحله 3/4: بررسی network-manager..."
    # if ! dpkg -s network-manager &> /dev/null; then
    #     echo "[!] بسته network-manager یافت نشد. ممکن است برای برخی تنظیمات شبکه لازم باشد."
    # fi

    # 4. بررسی دسترسی به curl (برای دانلود Xray)
    echo "[*] مرحله 3/4: بررسی دسترسی به curl (برای دانلود Xray)..."
    if ! command -v curl &> /dev/null; then
        echo "[!] بسته curl یافت نشد. در حال نصب..."
        if sudo apt install -y curl; then
            echo "[+] بسته curl با موفقیت نصب شد."
        else
            echo "[!] خطا در نصب بسته curl."
            exit 1
        fi
    else
        echo "[+] بسته curl از قبل نصب است."
    fi
    echo "[+] تمام وابستگی‌های ضروری نصب یا تایید شدند."
}

# === تابع برای نصب Xray Core ===
install_xray() {
    echo "[*] مرحله 4/4: دانلود و نصب Xray Core..."
    # تشخیص معماری سیستم
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) XRAY_ARCH="64" ;;
        amd64) XRAY_ARCH="64" ;;
        arm64) XRAY_ARCH="arm64" ;;
        aarch64) XRAY_ARCH="arm64" ;;
        *) echo "[!] معماری $ARCH پشتیبانی نمی‌شود."; exit 1 ;;
    esac

    # لینک دانلود آخرین ورژن (استفاده از curl برای دانلود)
    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${XRAY_ARCH}.zip"
    echo "[*] دانلود Xray Core از: $DOWNLOAD_URL"

    # دانلود و استخراج در یک پوشه موقت
    TEMP_DIR="/tmp/xray_install_$$" # استفاده از $$ برای منحصر به فرد کردن نام پوشه موقت
    mkdir -p "$TEMP_DIR"
    if curl -sL "$DOWNLOAD_URL" | unzip -q -o -d "$TEMP_DIR"; then
        echo "[+] دانلود و استخراج با موفقیت انجام شد."
    else
        echo "[!] خطا در دانلود یا استخراج Xray Core."
        rm -rf "$TEMP_DIR" # پاکسازی پوشه موقت در صورت خطا
        exit 1
    fi

    # جابجایی فایل اجرایی به مسیر نهایی و تنظیم مجوزها
    if [ -f "$TEMP_DIR/xray" ]; then
        sudo mv "$TEMP_DIR/xray" "$XRAY_BIN"
        sudo chmod +x "$XRAY_BIN"
        echo "[+] Xray Core در $XRAY_BIN نصب شد و قابل اجرا است."
    else
        echo "[!] فایل اجرایی 'xray' در $TEMP_DIR یافت نشد."
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # پاکسازی پوشه موقت
    rm -rf "$TEMP_DIR"

    # بررسی نهایی نصب
    if ! command -v "$XRAY_BIN" &> /dev/null; then
        echo "[!] نصب Xray Core ناموفق بود. لطفاً مسیر $XRAY_BIN را بررسی کنید."
        exit 1
    fi
}

# === تابع برای تنظیم systemd ===
setup_systemd() {
    echo "[*] تنظیم سرویس systemd برای $SERVICE_NAME..."
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

    # ایجاد فایل سرویس systemd
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Xray Service (VLESS + WS/gRPC)
After=network.target

[Service]
User=root
Group=root
Type=simple
Restart=on-failure
RestartSec=5s
# اضافه کردن پارامتر -config برای تعیین فایل کانفیگ
ExecStart=$XRAY_BIN -config $CONFIG_FILE
ExecStop=/bin/kill -SIGTERM \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

    # اعمال تغییرات systemd و فعال‌سازی سرویس
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    echo "[+] سرویس systemd برای $SERVICE_NAME تنظیم و فعال شد."
}

# === اجرای اصلی اسکریپت ===

echo "####################################################"
echo "#        اسکریپت نصب و راه‌اندازی Xray            #"
echo "####################################################"
echo ""

# 1. نصب وابستگی‌ها
install_dependencies

# 2. نصب یا بروزرسانی Xray Core
if ! command -v "$XRAY_BIN" &> /dev/null || ! "$XRAY_BIN" version &> /dev/null; then
    echo "[!] Xray Core یا یافت نشد یا نسخه آن نامعتبر است. در حال نصب/بروزرسانی..."
    install_xray
else
    echo "[*] Xray Core از قبل در $XRAY_BIN موجود است. از نسخه فعلی استفاده می‌شود."
    # اگر می‌خواهید همیشه آخرین نسخه را نصب کنید، خطوط install_xray() را از کامنت در بیاورید
    # echo "[*] در حال بروزرسانی Xray Core..."
    # install_xray
fi

# 3. ایجاد دایرکتوری کانفیگ و لاگ
echo "[*] ایجاد دایرکتوری‌های لازم برای کانفیگ و لاگ..."
sudo mkdir -p $(dirname $CONFIG_FILE)
sudo mkdir -p $LOG_DIR
sudo chmod 755 $LOG_DIR
echo "[+] دایرکتوری‌ها آماده شدند."

# 4. نوشتن فایل کانفیگ JSON
echo "[*] نوشتن فایل کانفیگ در $CONFIG_FILE..."
echo "$CONFIG_JSON" | sudo tee "$CONFIG_FILE" > /dev/null
if [ $? -ne 0 ]; then
    echo "[!] خطا در نوشتن فایل کانفیگ $CONFIG_FILE."
    exit 1
fi
echo "[+] فایل کانفیگ $CONFIG_FILE با موفقیت نوشته شد."

# 5. تنظیم و راه‌اندازی سرویس systemd
setup_systemd

echo "[*] راه‌اندازی سرویس $SERVICE_NAME..."
if sudo systemctl start $SERVICE_NAME; then
    echo "[+] سرویس $SERVICE_NAME با موفقیت راه‌اندازی شد."
    echo ""
    echo "========================================================"
    echo " تنظیمات کامل شد! 🎉"
    echo "========================================================"
    echo ""
    echo "[*] وضعیت سرویس را با دستور زیر بررسی کنید:"
    echo "    sudo systemctl status $SERVICE_NAME"
    echo ""
    echo "[*] برای مشاهده لاگ‌های زنده Xray:"
    echo "    sudo journalctl -u $SERVICE_NAME -f"
    echo ""
    echo "[*] دستورات مفید دیگر:"
    echo "    sudo systemctl stop $SERVICE_NAME    # توقف سرویس"
    echo "    sudo systemctl restart $SERVICE_NAME # ری‌استارت سرویس"
    echo "    sudo systemctl disable $SERVICE_NAME # غیرفعال کردن اجرای خودکار هنگام بوت"
    echo "    sudo systemctl enable $SERVICE_NAME  # فعال کردن اجرای خودکار هنگام بوت"
else
    echo "[!] خطا در راه‌اندازی سرویس $SERVICE_NAME."
    echo "[!] لطفاً وضعیت سرویس را با دستور 'sudo systemctl status $SERVICE_NAME' و لاگ‌ها را با 'sudo journalctl -u $SERVICE_NAME -f' بررسی کنید."
    exit 1
fi

exit 0
