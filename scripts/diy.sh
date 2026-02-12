#!/usr/bin/env bash
set -euo pipefail

mkdir -p files/etc/config
mkdir -p files/etc/uci-defaults

cat > files/etc/config/system <<'EOF'
config system
	option hostname 'HarryWrt'
	option timezone 'HKT-8'
	option zonename 'Asia/Hong_Kong'
	option ttylogin '0'
EOF

cat > files/etc/banner <<'EOF'
---------------------------------------------------------------
 _   _                           _  _   _  ____  _____
| | | | __ _ _ __ _ __ _   _    | || | | ||  _ \|_   _|
| |_| |/ _` | '__| '__| | | |   | || |_| || |_) | | |
|  _  | (_| | |  | |  | |_| |   |__   _  ||  _ <  | |
|_| |_|\__,_|_|  |_|   \__, |      |_| |_||_| \_\ |_|
                       |___/
---------------------------------------------------------------
 HarryWrt 24.10.5 | Lab Edition | Pure Performance
---------------------------------------------------------------
EOF

cat > files/etc/uci-defaults/99-harrywrt-custom <<'EOF'
#!/bin/sh

if [ -d /www/luci-static/argon ]; then
    uci set luci.main.mediaurlbase='/luci-static/argon'
    uci commit luci
fi

uci set dhcp.@dnsmasq[0].localservice='0' 2>/dev/null || true
uci commit dhcp

exit 0
EOF

chmod +x files/etc/uci-defaults/99-harrywrt-custom

echo "DIY script: HarryWrt shared configuration applied."
