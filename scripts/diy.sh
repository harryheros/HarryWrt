#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# HarryWrt DIY Script (OpenWrt 24.10.5 / Clean)
# - Fix geoview build: allow Go toolchain auto-download (Go >= 1.24)
# - Branding (banner/motd/DISTRIB_DESCRIPTION)
# - Force LuCI default theme to Bootstrap (Argon optional)
# ============================================================

FILES_DIR="files"
mkdir -p "${FILES_DIR}/etc/config" "${FILES_DIR}/etc/uci-defaults"

# ------------------------------------------------------------
# 0) Build-time fix: geoview requires Go >= 1.24
#    OpenWrt 24.10.x ships Go 1.23.x and locks GOTOOLCHAIN=local
#    Patch to auto so Go can fetch the needed toolchain.
# ------------------------------------------------------------
echo "[patch] enabling Go toolchain auto-download (GOTOOLCHAIN=auto)..."

# Patch golang-package.mk (THIS is usually the real source of GOTOOLCHAIN=local)
GOLANG_PKG_MK="feeds/packages/lang/golang/golang-package.mk"
if [ -f "$GOLANG_PKG_MK" ]; then
  # Replace exactly 'GOTOOLCHAIN=local' or 'GOTOOLCHAIN:=local' (with optional spaces)
  sed -i -E 's/(GOTOOLCHAIN\s*[:]?=)\s*local/\1auto/g' "$GOLANG_PKG_MK"
fi

# Patch golang-build.sh too (extra safety)
GOLANG_BUILD_SH="feeds/packages/lang/golang/golang-build.sh"
if [ -f "$GOLANG_BUILD_SH" ]; then
  sed -i -E 's/(GOTOOLCHAIN\s*[:]?=)\s*local/\1auto/g' "$GOLANG_BUILD_SH"
fi

# Last-resort: patch any other files under golang dir that may hardcode it
if [ -d "feeds/packages/lang/golang" ]; then
  find "feeds/packages/lang/golang" -type f -maxdepth 3 -print0 \
    | xargs -0 -I{} sed -i -E 's/(GOTOOLCHAIN\s*[:]?=)\s*local/\1auto/g' "{}" || true
fi

# Sanity check (fail fast if still locked anywhere)
if grep -RInE 'GOTOOLCHAIN\s*[:]?=\s*local\b' feeds/packages/lang/golang >/dev/null 2>&1; then
  echo "ERROR: still found GOTOOLCHAIN=local after patch (geoview will fail)" >&2
  grep -RInE 'GOTOOLCHAIN\s*[:]?=\s*local\b' feeds/packages/lang/golang | head -n 50 >&2 || true
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
# 3) MOTD
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/motd" <<'EOF'
HarryWrt 24.10.5 - Clean Edition (based on OpenWrt)
EOF

# ------------------------------------------------------------
# 4) Branding
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding" <<'EOF'
#!/bin/sh
set -eu

DESC="HarryWrt 24.10.5 Clean (based on OpenWrt)"

[ -f /etc/openwrt_release ] && sed -i "s/^DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION='${DESC}'/" /etc/openwrt_release 2>/dev/null || true
[ -f /etc/os-release ] && sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"${DESC}\"/" /etc/os-release 2>/dev/null || true
[ -f /usr/lib/os-release ] && sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"${DESC}\"/" /usr/lib/os-release 2>/dev/null || true

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding"

# ------------------------------------------------------------
# 5) Force LuCI default theme to Bootstrap (stock-like)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/99-force-default-theme" <<'EOF'
#!/bin/sh
set -eu

command -v uci >/dev/null 2>&1 || exit 0
uci -q set luci.main.mediaurlbase='/luci-static/bootstrap' || true
uci -q commit luci || true

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/99-force-default-theme"

echo "DIY script executed successfully."
