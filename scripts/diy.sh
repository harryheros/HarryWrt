#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# HarryWrt DIY Script (OpenWrt 24.10.5 / Clean)
# - Branding (banner/motd/DISTRIB_DESCRIPTION)
# - Keep stock-like LuCI look: Bootstrap as default theme
# - Build compatibility: Go toolchain policy patch (for newer modules)
# - Runtime compatibility helpers (service apply / first-boot kick)
# ============================================================

FILES_DIR="files"

mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"

# ------------------------------------------------------------
# 0) Build-time compatibility: Go toolchain policy
# ------------------------------------------------------------
echo "[patch] enabling Go toolchain auto policy ..."

GOLANG_PKG_MK="feeds/packages/lang/golang/golang-package.mk"
GOLANG_BUILD_SH="feeds/packages/lang/golang/golang-build.sh"

if [ -f "$GOLANG_PKG_MK" ]; then
  sed -i -E 's/\bGOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local\b/GOTOOLCHAIN=auto/g' "$GOLANG_PKG_MK"
fi

if [ -f "$GOLANG_BUILD_SH" ]; then
  sed -i -E 's/\bGOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local\b/GOTOOLCHAIN=auto/g' "$GOLANG_BUILD_SH"
fi

find feeds/packages/lang/golang -type f -print0 2>/dev/null | xargs -0 -r sed -i -E 's/\bGOTOOLCHAIN=[[:space:]]+auto\b/GOTOOLCHAIN=auto/g'

echo "[patch] toolchain policy patched OK."

# ------------------------------------------------------------
# 1) System defaults
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
# 3) MOTD
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/motd" <<'EOF'
HarryWrt 24.10.5 - Clean Edition (based on OpenWrt)
EOF

# ------------------------------------------------------------
# 4) UCI defaults: branding + release description
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding" <<'EOF'
#!/bin/sh
set -eu
DESC="HarryWrt 24.10.5 Clean (based on OpenWrt)"
if [ -f /etc/openwrt_release ]; then
  sed -i "s/^DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION='${DESC}'/" /etc/openwrt_release 2>/dev/null || true
fi
if [ -f /etc/os-release ]; then
  sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"${DESC}\"/" /etc/os-release 2>/dev/null || true
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding"

# ------------------------------------------------------------
# 5) Force LuCI default theme to Bootstrap
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/99-force-default-theme" <<'EOF'
#!/bin/sh
set -eu
if command -v uci >/dev/null 2>&1; then
  uci -q set luci.main.mediaurlbase='/luci-static/bootstrap' || true
  uci -q commit luci || true
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/99-force-default-theme"

# ------------------------------------------------------------
# 6) Apply-helper (ucitrack linkage for firewall)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/30-ucitrack-apply-helper" <<'EOF'
#!/bin/sh
set -eu
[ -f /etc/config/ucitrack ] || touch /etc/config/ucitrack
BASE_INIT="firewall dhcp"
BASE_AFFECTS="firewall dhcp"
if [ -x /etc/init.d/passwall2 ]; then
  BASE_INIT="${BASE_INIT} passwall2"
  BASE_AFFECTS="${BASE_AFFECTS} passwall2"
fi
uci -q set ucitrack.apply_helper='config'
uci -q set ucitrack.apply_helper.init="${BASE_INIT}"
uci -q set ucitrack.apply_helper.affects="${BASE_AFFECTS}"
uci -q set ucitrack.apply_helper.config='passwall2'
uci -q commit ucitrack
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/30-ucitrack-apply-helper"

# ------------------------------------------------------------
# 7) Musl loader fix (Core execution fix)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/98-firstboot-apply-kick" <<'EOF'
#!/bin/sh
set -eu
if [ ! -L /lib/ld-musl-x86_64.so.1 ] && [ -f /lib/libc.so ]; then
  ln -sf /lib/libc.so /lib/ld-musl-x86_64.so.1
fi
if [ -x /etc/init.d/passwall2 ]; then
  /etc/init.d/firewall restart >/dev/null 2>&1 || true
  /etc/init.d/passwall2 restart >/dev/null 2>&1 || true
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/98-firstboot-apply-kick"

echo "DIY script executed successfully."
