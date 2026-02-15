#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# HarryWrt DIY Script (OpenWrt 24.10.5 / Clean)
# - Branding & SSH Banner
# - Default LuCI theme forced to Bootstrap
# - Fix Go toolchain policy (GOTOOLCHAIN=auto)
# - Auto-fix Passwall2 Core Initialization (NO REBOOT NEEDED)
# ============================================================

FILES_DIR="files"
mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"

# ------------------------------------------------------------
# 0) Build-time fix: Go toolchain policy
# ------------------------------------------------------------
echo "[patch] enabling Go toolchain auto-download..."
GOLANG_PKG_MK="feeds/packages/lang/golang/golang-package.mk"
GOLANG_BUILD_SH="feeds/packages/lang/golang/golang-build.sh"

[ -f "$GOLANG_PKG_MK" ] && sed -i -E 's/\bGOTOOLCHAIN=local\b/GOTOOLCHAIN=auto/g' "$GOLANG_PKG_MK"
[ -f "$GOLANG_BUILD_SH" ] && sed -i -E 's/\bGOTOOLCHAIN=local\b/GOTOOLCHAIN=auto/g' "$GOLANG_BUILD_SH"

# Fix the "space after =" issue for sing-box
find feeds/packages/lang/golang -type f -print0 2>/dev/null | xargs -0 -r sed -i -E 's/\bGOTOOLCHAIN=[[:space:]]+auto\b/GOTOOLCHAIN=auto/g'

# ------------------------------------------------------------
# 1) System Branding & SSH Banner
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/config/system" <<'EOF'
config system
  option hostname 'HarryWrt'
  option timezone 'HKT-8'
  option zonename 'Asia/Hong_Kong'
EOF

cat > "${FILES_DIR}/etc/banner" <<'EOF'
---------------------------------------------------------------
 HarryWrt 24.10.5 | Clean Edition | x86_64
---------------------------------------------------------------
EOF

# ------------------------------------------------------------
# 2) Combined Setup Script (Branding + Theme + Passwall Fix)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/99-harrywrt-final-setup" <<'EOF'
#!/bin/sh

# 2.1 Branding Description
DESC="HarryWrt 24.10.5 Clean (based on OpenWrt)"
[ -f /etc/openwrt_release ] && sed -i "s/^DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION='${DESC}'/" /etc/openwrt_release

# 2.2 Force Bootstrap Theme
if command -v uci >/dev/null 2>&1; then
    uci -q set luci.main.mediaurlbase='/luci-static/bootstrap' || true
    uci -q commit luci || true
fi

# 2.3 Passwall2 Core Auto-Fix
# This runs the commands you used to run manually
if [ -x /etc/init.d/passwall2 ]; then
    /etc/init.d/firewall restart >/dev/null 2>&1
    sleep 2
    /etc/init.d/passwall2 restart >/dev/null 2>&1
fi

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/99-harrywrt-final-setup"

echo "DIY script executed successfully."
