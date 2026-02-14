#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# HarryWrt DIY Script (OpenWrt 24.10.5 / Clean)
# - Build-time patch: allow Go toolchain auto-download (Go >= 1.24) for geoview
# - Branding (banner/motd/DISTRIB_DESCRIPTION)
# - Force LuCI default theme to Bootstrap (Argon remains optional)
# ============================================================

FILES_DIR="files"

mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"

# ------------------------------------------------------------
# 0) Build-time fix: geoview requires Go >= 1.24
#    OpenWrt 24.10.x ships Go 1.23.x and locks GOTOOLCHAIN=local in golang-package.mk
#    Patch to GOTOOLCHAIN=auto so Go can fetch the needed toolchain during build.
#
#    IMPORTANT:
#    - This must run AFTER feeds update/install (so feeds/packages exists),
#      and BEFORE make defconfig / make.
# ------------------------------------------------------------
echo "[patch] enabling Go toolchain auto-download (GOTOOLCHAIN=auto) for geoview..."

GOLANG_DIR="feeds/packages/lang/golang"
if [ -d "$GOLANG_DIR" ]; then
  # Patch Makefile/shell-style assignments:
  #   GOTOOLCHAIN=local
  #   GOTOOLCHAIN := local
  #   export GOTOOLCHAIN=local
  find "$GOLANG_DIR" -type f \( -name "*.mk" -o -name "*.sh" -o -name "Makefile" \) -print0 \
    | xargs -0 sed -i -E \
      's/^([[:space:]]*(export[[:space:]]+)?)GOTOOLCHAIN([[:space:]]*:?=)[[:space:]]*local/\1GOTOOLCHAIN\3 auto/g'

  # Sanity check: fail fast if still locked
  if grep -RInE '^[[:space:]]*(export[[:space:]]+)?GOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local' "$GOLANG_DIR" >/dev/null 2>&1; then
    echo "ERROR: still found GOTOOLCHAIN=local after patch (geoview will fail)" >&2
    grep -RInE '^[[:space:]]*(export[[:space:]]+)?GOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local' "$GOLANG_DIR" | head -n 30 >&2 || true
    exit 1
  fi
else
  echo "ERROR: $GOLANG_DIR not found. Did you run feeds update/install before this DIY script?" >&2
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
#    Use 99 to ensure it runs last, even if other uci-defaults exist.
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
