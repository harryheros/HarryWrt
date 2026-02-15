#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# HarryWrt DIY Script (OpenWrt 24.10.5 / Clean)
# - Branding (banner/motd/DISTRIB_DESCRIPTION)
# - Force LuCI default theme to Bootstrap (Argon remains optional)
# - Fix Go toolchain lock for geoview (Go >= 1.24): GOTOOLCHAIN=auto
# ============================================================

FILES_DIR="files"

mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"

# ------------------------------------------------------------
# 0) Build-time fix: allow Go toolchain auto-download
#    IMPORTANT:
#    - Patch ONLY specific files to avoid "mass sed" corrupting .mk files
#    - Ensure NO leading spaces: must be GOTOOLCHAIN=auto (not " auto")
# ------------------------------------------------------------
echo "[patch] enabling Go toolchain auto-download (GOTOOLCHAIN=auto) ..."

GOLANG_DIR="feeds/packages/lang/golang"

patch_gotoolchain_file() {
  local f="$1"
  [ -f "$f" ] || return 0

  # Replace:
  #   <spaces>GOTOOLCHAIN=local
  #   <spaces>GOTOOLCHAIN:=local
  #   <spaces>GOTOOLCHAIN ?= local
  # into:
  #   same assignment operator, value becomes "auto" with NO leading spaces
  sed -i -E "s/^([[:space:]]*GOTOOLCHAIN[[:space:]]*[:?]?=)[[:space:]]*local/\1auto/g" "$f"

  # Some files may use export form
  sed -i -E "s/^([[:space:]]*export[[:space:]]+GOTOOLCHAIN=)[[:space:]]*local/\1auto/g" "$f"
}

# Patch the two known lock points
patch_gotoolchain_file "${GOLANG_DIR}/golang-build.sh"
patch_gotoolchain_file "${GOLANG_DIR}/golang-package.mk"

# Also patch any other .mk that might define it (safe: only .mk files, only exact var)
if [ -d "$GOLANG_DIR" ]; then
  while IFS= read -r -d '' f; do
    patch_gotoolchain_file "$f"
  done < <(find "$GOLANG_DIR" -maxdepth 2 -type f \( -name "*.mk" -o -name "*.sh" \) -print0)
fi

# Sanity check: fail fast if still locked OR if someone produced "GOTOOLCHAIN= auto"
if grep -RInE "^[[:space:]]*GOTOOLCHAIN[[:space:]]*[:?]?=[[:space:]]*local" "$GOLANG_DIR" >/dev/null 2>&1; then
  echo "ERROR: still found GOTOOLCHAIN=local after patch" >&2
  grep -RInE "^[[:space:]]*GOTOOLCHAIN[[:space:]]*[:?]?=[[:space:]]*local" "$GOLANG_DIR" | head -n 50 >&2 || true
  exit 1
fi

if grep -RInE "^[[:space:]]*GOTOOLCHAIN[[:space:]]*[:?]?=[[:space:]]+auto" "$GOLANG_DIR" >/dev/null 2>&1; then
  echo "ERROR: found leading-space value 'GOTOOLCHAIN= auto' (will break builds)" >&2
  grep -RInE "^[[:space:]]*GOTOOLCHAIN[[:space:]]*[:?]?=[[:space:]]+auto" "$GOLANG_DIR" | head -n 50 >&2 || true
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
# 4) UCI defaults: Branding (DISTRIB_DESCRIPTION / PRETTY_NAME)
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
# 5) Force LuCI default theme to official Bootstrap (stock-like)
#    Argon remains installed but NOT default
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
