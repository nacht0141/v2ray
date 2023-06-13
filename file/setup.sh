#!/bin/bash
sudo apt install software-properties-common -y
sudo add-apt-repository ppa:certbot/certbot -y
sudo apt-get update -y
sudo apt-get install certbot zip unzip curl wget -y
#buat dir
sudo mkdir -p /etc/v2ray/vless
sudo mkdir -p /etc/v2ray/trojan
sudo mkdir -p /etc/v2ray/vmess
sudo mkdir /etc/v2ray/config
clear
echo "[!] Installasi certificate ..."
read -p "Masukkan domain Anda: " domain
sudo certbot certonly --standalone --preferred-challenges http --agree-tos --register-unsafely-without-email -d $domain
if [ $? -eq 0 ]
then
    echo "Sertifikat berhasil diperoleh untuk domain $domain."
    echo "$domain" > /etc/v2ray/domain.txt
else
    clear
    echo "Gagal mendapatkan sertifikat untuk domain $domain."
    exit 1
fi
wget https://github.com/v2fly/v2ray-core/releases/latest/download/v2ray-linux-64.zip
unzip v2ray-linux-64.zip -d v2ray
sudo cp v2ray/v2ray /usr/bin/
sudo cp v2ray/v2ctl /usr/bin/
sudo cp v2ray/geoip-only-cn-private.dat /usr/bin/
sudo cp v2ray/geosite.dat /usr/bin/
sudo cp v2ray/geoip.dat /usr/bin
rm -rf v2ray 
rm -f v2ray-linux-64.zip
#vmess
sudo tee /etc/v2ray/config/config.json <<EOF
{
  "log": {
  "access": "/var/log/v2ray/access.log",
  "error": "/var/log/v2ray/error.log",
  "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 80,
      "protocol": "vmess",
      "settings": {
        "clients": [
        {
            "id": "1342284b-b0bb-4f79-b901-40e2a7e90e39",
            "alterId": 0
          }
        ],
        "disableInsecureEncryption": true
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/ws"
        }
      }
    },
    {
      "port": 443,
      "protocol": "vmess",
      "settings": {
        "clients": [
        {
            "id": "1342284b-b0bb-4f79-b901-40e2a7e90e39",
            "alterId": 0
          }
        ],
        "disableInsecureEncryption": true
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/letsencrypt/live/${domain}/fullchain.pem",
              "keyFile": "/etc/letsencrypt/live/${domain}/privkey.pem"
            }
          ]
        },
        "wsSettings": {
          "path": "/wstls"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
#vless
sudo tee /etc/v2ray/config/vless.json <<EOF
{
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 8880,
      "protocol": "vless",
      "settings": {
        "clients": [
        {
            "id": "4f1f0428-7483-4958-b70f-f0ce400593cc",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vlessws",
          "headers": {
            "Host": ""
          }
        }
      }
    },
    {
      "port": 8443,
      "protocol": "vless",
      "settings": {
        "clients": [
        {
            "id": "4f1f0428-7483-4958-b70f-f0ce400593cc",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/letsencrypt/live/${domain}/fullchain.pem",
              "keyFile": "/etc/letsencrypt/live/${domain}/privkey.pem"
            }
          ]
        },
        "wsSettings": {
          "path": "/vlesstls",
          "headers": {
            "Host": ""
          }
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
#trojan
sudo tee /etc/v2ray/config/trojan.json <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": 2087,
      "protocol": "trojan",
      "settings": {
        "clients": [
        {
            "password": "fSogCBVwH5JIg_sHJdwuSg",
            "level": 8
          }
        ],
        "fallbacks": [
          {
            "dest": "www.google.com:443"
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "trgrpc"
        },
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/letsencrypt/live/${domain}/fullchain.pem",
              "keyFile": "/etc/letsencrypt/live/${domain}/privkey.pem"
            }
          ]
        }
      },
      "tag": "trojan-inbound"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "outboundTag": "direct",
        "ip": [
          "geoip:private"
        ]
      }
    ]
  }
}
EOF
# Buat direktori log
sudo mkdir -p /var/log/v2ray/
sudo tee /etc/systemd/system/v2ray.service <<EOF
[Unit]
Description=V2Ray Service
After=network.target

[Service]
User=root
Group=root
Restart=always
ExecStart=/usr/bin/v2ray run -config /etc/v2ray/config/config.json
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
sudo tee /etc/systemd/system/v2ray@.service <<EOF
[Unit]
Description=V2Ray Service
After=network.target

[Service]
User=root
Group=root
Restart=always
ExecStart=/usr/bin/v2ray run -config /etc/v2ray/config/%i.json
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
clear
systemctl daemon-reload
systemctl enable v2ray
systemctl enable v2ray@vless
systemctl enable v2ray@trojan
systemctl start v2ray
systemctl start v2ray@vless
systemctl start v2ray@trojan
#auto delete
sudo timedatectl set-timezone Asia/Jakarta
sudo timedatectl set-ntp true
echo "59 23 * * * root /etc/v2ray/auto-exp" | sudo tee -a /etc/crontab > /dev/null
#install menu
wget -P /usr/bin https://raw.githubusercontent.com/nacht0141/v2ray/main/file/add-trojan
wget -P /usr/bin https://raw.githubusercontent.com/nacht0141/v2ray/main/file/add-vmess
wget -P /usr/bin https://raw.githubusercontent.com/nacht0141/v2ray/main/file/add-vless
wget -P /usr/bin https://raw.githubusercontent.com/nacht0141/v2ray/main/file/del-trojan
wget -P /usr/bin https://raw.githubusercontent.com/nacht0141/v2ray/main/file/del-vmess
wget -P /usr/bin https://raw.githubusercontent.com/nacht0141/v2ray/main/file/del-vless
wget -P /usr/bin https://raw.githubusercontent.com/nacht0141/v2ray/main/file/chk-trojan
wget -P /usr/bin https://raw.githubusercontent.com/nacht0141/v2ray/main/file/chk-vmess
wget -P /usr/bin https://raw.githubusercontent.com/nacht0141/v2ray/main/file/chk-vless
wget -P /usr/bin https://raw.githubusercontent.com/nacht0141/v2ray/main/file/menu-trojan
wget -P /usr/bin https://raw.githubusercontent.com/nacht0141/v2ray/main/file/menu-vmess
wget -P /usr/bin https://raw.githubusercontent.com/nacht0141/v2ray/main/file/menu-vless
wget -P /usr/bin https://raw.githubusercontent.com/nacht0141/v2ray/main/file/menu
wget -O /usr/bin/speedtest https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py
wget -P /etc/v2ray https://raw.githubusercontent.com/nacht0141/v2ray/main/file/auto-exp
chmod +x /usr/bin/add-trojan
chmod +x /usr/bin/add-vmess
chmod +x /usr/bin/add-vless
chmod +x /usr/bin/del-trojan
chmod +x /usr/bin/del-vmess
chmod +x /usr/bin/del-vless
chmod +x /usr/bin/chk-trojan
chmod +x /usr/bin/chk-vmess
chmod +x /usr/bin/chk-vless
chmod +x /usr/bin/menu-trojan
chmod +x /usr/bin/menu-vmess
chmod +x /usr/bin/menu-vless
chmod +x /usr/bin/menu
chmod +x /usr/bin/speedtest
chmod +x /etc/v2ray/auto-exp
clear
echo "[!] Installasi selesai silahkan ketik menu untuk menampilkan menu..."