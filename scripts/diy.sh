#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# HarryWrt DIY Script (OpenWrt 24.10.5 / Clean)
# - Branding (banner/motd/DISTRIB_DESCRIPTION)
# - Default LuCI theme forced to Bootstrap (Argon remains optional)
# - Fix Go toolchain policy for geoview (Go >= 1.24): GOTOOLCHAIN=auto
# - Post-install auto-fix for Passwall2 Core (Ensures first-run success)
# ============================================================

FILES_DIR="files"
mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"

# ------------------------------------------------------------
# 0) Build-time fix: Go toolchain policy for geoview
#    Using your SUCCESSFUL regex: exact match, no mass sed.
# ------------------------------------------------------------
echo "[patch] enabling Go toolchain auto-download (GOTOOLCHAIN=auto) ..."

GOLANG_PKG_MK="feeds/packages/lang/golang/golang-package.mk"
GOLANG_BUILD_SH="feeds/packages/lang/golang/golang-build.sh"

# Use the precise replacement that you proved works
[ -f "$GOLANG_PKG_MK" ] && sed -i -E 's/\bGOTOOLCHAIN=local\b/GOTOOLCHAIN=auto/g' "$GOLANG_PKG_MK"
[ -f "$GOLANG_BUILD_SH" ] && sed -i -E 's/\bGOTOOLCHAIN=local\b/GOTOOLCHAIN=auto/g' "$GOLANG_BUILD_SH"

# Clean up accidental spaces (the sing-box fix)
find feeds/packages/lang/golang -type f -print0 2>/dev/null | xargs -0 -r sed -i -E 's/\bGOTOOLCHAIN=[[:space:]]+auto\b/GOTOOLCHAIN=auto/g'

# Sanity check
if grep -RInE '\bGOTOOLCHAIN=[[:space:]]+auto\b' feeds/packages/lang/golang >/dev/null 2>&1; then
  echo "ERROR: found 'GOTOOLCHAIN= auto'. Build will fail." >&2
  exit 1
fi

echo "[patch] Go toolchain policy patched OK."

# ------------------------------------------------------------
# 1) System defaults (HarryWrt Branding)
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
# 2) SSH banner & MOTD
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
---------------------------------------------------------------
EOF

cat > "${FILES_DIR}/etc/motd" <<'EOF'
HarryWrt 24.10.5 - Clean Edition (based on OpenWrt)
EOF

# ------------------------------------------------------------
# 3) UCI defaults: branding + theme + PASSWALL FIX
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/90-harrywrt-setup" <<'EOF'
#!/bin/sh
set -eu

# 3.1 Branding
DESC="HarryWrt 24.10.5 Clean (based on OpenWrt)"
[ -f /etc/openwrt_release ] && sed -i "s/^DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION='${DESC}'/" /etc/openwrt_release
[ -f /etc/os-release ] && sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"${DESC}\"/" /etc/os-release

# 3.2 Force Bootstrap Theme
if command -v uci >/dev/null 2>&1; then
  uci -q set luci.main.mediaurlbase='/luci-static/bootstrap' || true
  uci -q commit luci || true
fi

# 3.3 Passwall2 Core Auto-Fix (Runs on first boot or after install)
# This solves your "Core not running until reboot" issue.
if [ -x /etc/init.d/passwall2 ] && [ ! -f /etc/passwall2_init_done ]; then
    /etc/init.d/firewall restart >/dev/null 2>&1
    sleep 2
    /etc/init.d/passwall2 restart >/dev/null 2>&1
    touch /etc/passwall2_init_done
fi

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/90-harrywrt-setup"

echo "DIY script executed successfully."
