#!/bin/bash

# نام فایل کانفیگ JSON
CONFIG_FILE="xray_config.json"
XRAY_EXECUTABLE="/usr/local/bin/xray"

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
"$XRAY_EXECUTABLE" run -config "$CONFIG_FILE" &

# چند ثانیه صبر برای اطمینان از راه‌اندازی
sleep 5
echo "Xray should be running now."
