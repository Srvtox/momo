#!/bin/bash

# نام فایل کانفیگ JSON
CONFIG_FILE="xray_config.json"
XRAY_EXECUTABLE="/usr/local/bin/xray"

if [ ! -f "/usr/local/bin/xray" ]; then
    echo "📥 Downloading Xray Core..."
    wget -q https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
    sudo unzip -q -o Xray-linux-64.zip -d /usr/local/bin/xray
    sudo chmod +x /usr/local/bin/xray
    rm Xray-linux-64.zip
    echo "✅ Xray Installed."
else
    echo "✔ Xray is already there."
fi

# --- ۲. ایجاد فایل کانفیگ JSON ---
echo "📝 Creating Xray config file: $CONFIG_FILE..."
cat << EOF > "$CONFIG_FILE"
{
  "log": {
    "loglevel": "none"
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
          "tcpNoDelay": true
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
}
EOF
echo "Config file created successfully."

# --- ۳. اجرای Xray ---
echo "🚀 Starting Xray with config file: $CONFIG_FILE..."
# اجرای Xray در پس‌زمینه
/usr/local/bin/xray run -config "$CONFIG_FILE" &

# چند ثانیه صبر برای اطمینان از راه‌اندازی
sleep 10
echo "Xray should be running now."

# --- ۶. بررسی وضعیت Xray ---
echo "🔍 Checking Xray status..."
# دستور ss رو اجرا می‌کنیم و دنبال پورت‌های 8888 و 8889 می‌گردیم
# L: نمایش لیست سوکت‌ها، N: نمایش آدرس‌ها به صورت عددی (IP:Port)، t: TCP، u: UDP
# -l: فقط سوکت‌های در حال شنود (listening) رو نشون بده
# --tcp: فقط سوکت‌های TCP رو نشون بده
# --numeric: از تبدیل نام IP به نام دامنه خودداری کن (برای سرعت)
# grep 8888 یا grep 8889: فقط خطوطی که حاوی شماره پورت مورد نظر ما هستند رو نشون بده

echo "--- Xray Inbound Ports ---"
sudo ss -ltn --numeric | grep -E ':8888|:8889' || echo "Xray ports 8888 or 8889 not found listening."

echo "--- Xray Process Check ---"
# چک می‌کنیم که پروسه xray در حال اجرا باشه
if pgrep -f "$XRAY_EXECUTABLE" > /dev/null; then
    echo "✅ Xray process is running."
else
    echo "❌ Xray process is NOT running. Check logs for errors."
fi
echo "--------------------------"

# بقیه دستورات مثل sleep 900 و ...

