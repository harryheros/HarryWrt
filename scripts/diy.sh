#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# HarryWrt DIY Script (OpenWrt 24.10.5 / Clean)
# - Build-time fix: geoview requires Go >= 1.24 (GOTOOLCHAIN=auto)
# - Branding (banner/motd/DISTRIB_DESCRIPTION)
# - Force default LuCI theme to Bootstrap (Argon remains optional)
# ============================================================

FILES_DIR="files"

mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"

# ------------------------------------------------------------
# 0) Build-time fix: geoview requires Go >= 1.24
#    OpenWrt 24.10.x ships Go 1.23.x and locks GOTOOLCHAIN=local in golang mk.
#    Patch ONLY golang feed files to allow auto toolchain download.
#    IMPORTANT: keep "GOTOOLCHAIN=auto" with NO spaces.
# ------------------------------------------------------------
echo "[patch] enabling Go toolchain auto-download (GOTOOLCHAIN=auto) ..."

GOLANG_DIR="feeds/packages/lang/golang"

if [ -d "${GOLANG_DIR}" ]; then
  # Patch both "GOTOOLCHAIN=local" and "GOTOOLCHAIN:=local"
  # Also normalize accidental "GOTOOLCHAIN= auto" -> "GOTOOLCHAIN=auto"
  find "${GOLANG_DIR}" -type f -print0 | xargs -0 sed -i \
    -e 's/^[[:space:]]*GOTOOLCHAIN[[:space:]]*=[[:space:]]*local[[:space:]]*$/GOTOOLCHAIN=auto/g' \
    -e 's/^[[:space:]]*GOTOOLCHAIN[[:space:]]*:=[[:space:]]*local[[:space:]]*$/GOTOOLCHAIN:=auto/g' \
    -e 's/GOTOOLCHAIN[[:space:]]*=[[:space:]]*auto/GOTOOLCHAIN=auto/g' \
    -e 's/GOTOOLCHAIN[[:space:]]*:[[:space:]]*=[[:space:]]*auto/GOTOOLCHAIN:=auto/g'

  # Fail fast if still locked to local anywhere
  if grep -RInE '^[[:space:]]*GOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local([[:space:]]*$)' "${GOLANG_DIR}" >/dev/null 2>&1; then
    echo "ERROR: still found GOTOOLCHAIN=local after patch" >&2
    grep -RInE '^[[:space:]]*GOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local([[:space:]]*$)' "${GOLANG_DIR}" | head -n 50 >&2 || true
    exit 1
  fi

  echo "[patch] Go toolchain policy patched OK."
else
  echo "[patch] WARNING: ${GOLANG_DIR} not found (feeds not installed yet?)"
fi

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
# 4) UCI defaults: branding (release description)
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
#    Use 99 to ensure it runs LAST.
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
