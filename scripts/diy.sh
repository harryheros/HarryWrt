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
#    Defense-grade regex to match both '=' and ':='
#    Ensures exactly "GOTOOLCHAIN=auto" with NO SPACE.
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

if grep -RInE '\bGOTOOLCHAIN=[[:space:]]+auto\b' feeds/packages/lang/golang >/dev/null 2>&1; then
  echo "ERROR: found 'GOTOOLCHAIN= auto' (space). Aborting." >&2
  grep -RInE '\bGOTOOLCHAIN=[[:space:]]+auto\b' feeds/packages/lang/golang | head -n 50 >&2 || true
  exit 1
fi

if grep -RInE '\bGOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local\b' feeds/packages/lang/golang >/dev/null 2>&1; then
  echo "ERROR: toolchain policy still locked to local. Aborting." >&2
  grep -RInE '\bGOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local\b' feeds/packages/lang/golang | head -n 50 >&2 || true
  exit 1
fi

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
if [ -f /usr/lib/os-release ]; then
  sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"${DESC}\"/" /usr/lib/os-release 2>/dev/null || true
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding"

# ------------------------------------------------------------
# 5) Force LuCI default theme to Bootstrap (stock-like)
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
# 6) Apply-helper: keep it quiet when optional services are not installed
#    - Always: firewall + dhcp
#    - Optional: only append service name if its init script exists
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/30-ucitrack-apply-helper" <<'EOF'
#!/bin/sh
set -eu

# Ensure ucitrack config exists
[ -f /etc/config/ucitrack ] || touch /etc/config/ucitrack

# Base services are always present in a clean build
BASE_INIT="firewall dhcp"
BASE_AFFECTS="firewall dhcp"

# Optionally add extra service if installed later (avoid log noise)
if [ -x /etc/init.d/passwall2 ]; then
  BASE_INIT="${BASE_INIT} passwall2"
  BASE_AFFECTS="${BASE_AFFECTS} passwall2"
fi

uci -q delete ucitrack.apply_helper >/dev/null 2>&1 || true
uci -q set ucitrack.apply_helper='config'
uci -q set ucitrack.apply_helper.init="${BASE_INIT}"
uci -q set ucitrack.apply_helper.affects="${BASE_AFFECTS}"
# Track config name (harmless even if not present; no init is called unless listed)
uci -q set ucitrack.apply_helper.config='passwall2'
uci -q commit ucitrack

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/30-ucitrack-apply-helper"

# ------------------------------------------------------------
# 7) One-time first boot kick (only if optional service already exists)
#    + musl loader symlink fix (safe, neutral, zero side effects)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/98-firstboot-apply-kick" <<'EOF'
#!/bin/sh
set -eu
STAMP="/etc/firstboot_apply_kicked"
[ -f "$STAMP" ] && exit 0

# Fix musl loader symlink if needed (prevents "-ash: not found" style issues)
if [ ! -L /lib/ld-musl-x86_64.so.1 ] && [ -f /lib/libc.so ]; then
  ln -sf /lib/libc.so /lib/ld-musl-x86_64.so.1
fi

# Only act if optional init script exists
if [ -x /etc/init.d/passwall2 ]; then
  /etc/init.d/firewall restart >/dev/null 2>&1 || true
  sleep 2
  /etc/init.d/passwall2 restart >/dev/null 2>&1 || true
fi

touch "$STAMP"
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/98-firstboot-apply-kick"

echo "DIY script executed successfully."
