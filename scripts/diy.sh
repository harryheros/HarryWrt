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
  option log_proto 'stderr'
  option conloglevel '8'
  option cronloglevel '5'
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
 HarryWrt 24.10.5 | Clean Edition | Stable Base
---------------------------------------------------------------
EOF

cat > files/etc/uci-defaults/99-harrywrt-settings <<'EOF'
#!/bin/sh

uci -q set luci.main.mediaurlbase='/luci-static/argon'
uci -q commit luci

exit 0
EOF

chmod +x files/etc/uci-defaults/99-harrywrt-settings

echo "DIY script executed successfully."
