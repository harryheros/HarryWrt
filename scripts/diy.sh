#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# HarryWrt DIY Script (OpenWrt 24.10.5 / Clean)
# - Branding (banner/motd/DISTRIB_DESCRIPTION)
# - Default LuCI theme forced to Bootstrap (Argon remains optional)
# - Fix Go toolchain policy for geoview (Go >= 1.24): GOTOOLCHAIN=auto
# - Auto-fix Passwall2 core init on first boot (only if installed)
# ============================================================

FILES_DIR="files"

mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"

# ------------------------------------------------------------
# 0) Build-time fix: Go toolchain policy for geoview
#    OpenWrt 24.10.x uses Go 1.23.x, and feeds may force GOTOOLCHAIN=local.
#    We patch both '=' and ':=' to ensure GOTOOLCHAIN=auto (NO SPACE).
# ------------------------------------------------------------
echo "[patch] enabling Go toolchain auto-download (GOTOOLCHAIN=auto) ..."

GOLANG_PKG_MK="feeds/packages/lang/golang/golang-package.mk"
GOLANG_BUILD_SH="feeds/packages/lang/golang/golang-build.sh"

# Patch 0.1 & 0.2: Broad match for both '=' and ':=' to prevent bypass
# Use [[:space:]]* to handle any spacing around the assignment operator
if [ -f "$GOLANG_PKG_MK" ]; then
  sed -i -E 's/\bGOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local\b/GOTOOLCHAIN=auto/g' "$GOLANG_PKG_MK"
fi

if [ -f "$GOLANG_BUILD_SH" ]; then
  sed -i -E 's/\bGOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local\b/GOTOOLCHAIN=auto/g' "$GOLANG_BUILD_SH"
fi

# Patch 0.3: Extra safety for potential "GOTOOLCHAIN= auto" (space after '=')
# This handles the specific failure seen in sing-box builds
find feeds/packages/lang/golang -type f -print0 2>/dev/null | xargs -0 -r sed -i -E 's/\bGOTOOLCHAIN=[[:space:]]+auto\b/GOTOOLCHAIN=auto/g'

# Patch 0.4 sanity check (fail fast)
# Verify no 'local' remain and no broken 'GOTOOLCHAIN= auto' exist
if grep -RInE '\bGOTOOLCHAIN([[:space:]]*:?=[[:space:]]*local|=[[:space:]]+auto)\b' feeds/packages/lang/golang >/dev/null 2>&1; then
  echo "ERROR: GOTOOLCHAIN patch failed or created invalid syntax (space after =)." >&2
  grep -RInE '\bGOTOOLCHAIN([[:space:]]*:?=[[:space:]]*local|=[[:space:]]+auto)\b' feeds/packages/lang/golang | head -n 20 >&2 || true
  exit 1
fi

echo "[patch] Go toolchain policy patched OK."

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
# 6) Auto-fix Passwall2 Core Initialization
#    Ensures firewall rules apply correctly on first boot/install
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/99-passwall2-autofix" <<'EOF'
#!/bin/sh
set -eu

MARK="/etc/passwall2_autofix_done"

# Only act if passwall2 is present
[ -x /etc/init.d/passwall2 ] || exit 0
[ -f "$MARK" ] && exit 0

# Restart firewall to ensure nftables rules are loaded
/etc/init.d/firewall restart >/dev/null 2>&1 || true
sleep 2

# Restart passwall2 service
/etc/init.d/passwall2 restart >/dev/null 2>&1 || true

touch "$MARK" 2>/dev/null || true
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/99-passwall2-autofix"

echo "DIY script executed successfully."
