#!/usr/bin/env bash
set -euo pipefail

FILES_DIR="files"
UCI_DEFAULTS_DIR="${FILES_DIR}/etc/uci-defaults"
CFG_DIR="${FILES_DIR}/etc/config"

mkdir -p "${CFG_DIR}" "${UCI_DEFAULTS_DIR}"

cat > "${CFG_DIR}/system" <<'EOF'
config system
  option hostname 'HarryWrt'
  option timezone 'HKT-8'
  option zonename 'Asia/Hong_Kong'
  option ttylogin '0'
  option log_proto 'stderr'
  option conloglevel '8'
  option cronloglevel '5'
EOF

cat > "${FILES_DIR}/etc/banner" <<'EOF'
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

cat > "${UCI_DEFAULTS_DIR}/99-harrywrt-settings" <<'EOF'
#!/bin/sh

uci -q set luci.main.mediaurlbase='/luci-static/argon'
uci -q commit luci

exit 0
EOF

chmod 0755 "${UCI_DEFAULTS_DIR}/99-harrywrt-settings"

echo "DIY script executed successfully."
