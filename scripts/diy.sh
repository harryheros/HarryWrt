#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# HarryWrt DIY Script (OpenWrt 24.10.5 / Clean)
# - Branding (banner/motd/DISTRIB_DESCRIPTION)
# - Default LuCI theme forced to Bootstrap (Argon remains optional)
# - Fix geoview build: allow Go toolchain auto-download (Go >= 1.24)
# ============================================================

FILES_DIR="files"

mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"

# ------------------------------------------------------------
# 0) Build-time fix: geoview requires Go >= 1.24
#    OpenWrt 24.10.x ships Go 1.23.x and locks GOTOOLCHAIN=local
#    Patch to GOTOOLCHAIN=auto so Go can fetch the needed toolchain.
#    MUST run before make defconfig / compilation.
# ------------------------------------------------------------
echo "[patch] enabling Go toolchain auto-download (GOTOOLCHAIN=auto) for geoview..."

# 0.1 patch golang-build.sh
if [ -f "feeds/packages/lang/golang/golang-build.sh" ]; then
  sed -i 's/GOTOOLCHAIN=local/GOTOOLCHAIN=auto/g' "feeds/packages/lang/golang/golang-build.sh"
else
  # fallback for different feeds layout
  find "feeds/packages/lang/golang" -name "golang-build.sh" -exec sed -i 's/GOTOOLCHAIN=local/GOTOOLCHAIN=auto/g' {} + || true
fi

# 0.2 patch golang-package.mk (double insurance)
if [ -f "feeds/packages/lang/golang/golang-package.mk" ]; then
  sed -i 's/^GOTOOLCHAIN:=local$/GOTOOLCHAIN:=auto/g' "feeds/packages/lang/golang/golang-package.mk" || true
fi

# 0.3 sanity check: fail fast if still locked
if grep -RIn "GOTOOLCHAIN=local" "feeds/packages/lang/golang" >/dev/null 2>&1; then
  echo "ERROR: still found GOTOOLCHAIN=local after patch (geoview will fail)" >&2
  grep -RIn "GOTOOLCHAIN=local" "feeds/packages/lang/golang" | head -n 30 >&2 || true
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
# 4) UCI defaults: Branding + release description
#    (best-effort; won't break if file format differs)
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

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding"

# ------------------------------------------------------------
# 5) Force LuCI default theme to Bootstrap (stock-like)
#    Use 99 to ensure it runs last.
#    Argon can still be selected manually later.
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

echo "DIY script executed successfully."
