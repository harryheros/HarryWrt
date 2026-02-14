#!/usr/bin/env bash
set -euo pipefail

FILES_DIR="files"

mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"

# ------------------------------------------------------------
# 1) System defaults (hostname, timezone)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/config/system" <<'EOF'
config system
  option hostname 'HarryWrt'
  option timezone 'HKT-8'
  option zonename 'Asia/Hong_Kong'
  option ttylogin '0'
  option log_proto 'stderr'
  option conloglevel '8'
  option cronloglevel '5'
EOF

# ------------------------------------------------------------
# 2) SSH login banner
# ------------------------------------------------------------
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
 Based on OpenWrt | No Bloatware | Performance Focused
---------------------------------------------------------------
EOF

# ------------------------------------------------------------
# 3) MOTD (post-login message)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/motd" <<'EOF'
HarryWrt 24.10.5 - Clean Edition (based on OpenWrt)
EOF

# ------------------------------------------------------------
# 4) UCI defaults: branding + LuCI default theme
#    - Keep Argon installed as an option
#    - Force default theme to bootstrap for a stock-like experience
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding" <<'EOF'
#!/bin/sh
set -eu

DESC="HarryWrt 24.10.5 Clean (based on OpenWrt)"

# Update release descriptions (best-effort)
if [ -f /etc/openwrt_release ]; then
  sed -i "s/^DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION='${DESC}'/" /etc/openwrt_release 2>/dev/null || true
fi

if [ -f /etc/os-release ]; then
  sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"${DESC}\"/" /etc/os-release 2>/dev/null || true
fi

if [ -f /usr/lib/os-release ]; then
  sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"${DESC}\"/" /usr/lib/os-release 2>/dev/null || true
fi

# Force LuCI default theme to bootstrap (Argon remains available to switch)
if command -v uci >/dev/null 2>&1; then
  uci -q set luci.main.mediaurlbase='/luci-static/bootstrap' || true
  uci -q commit luci || true
fi

exit 0
EOF

chmod 0755 "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding"

echo "DIY script executed successfully."
