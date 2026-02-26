#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# HarryWrt DIY Script (OpenWrt 24.10.5 / Clean)
# - Branding (banner/motd/DISTRIB_DESCRIPTION)
# - Default LuCI theme forced to Bootstrap (Argon remains optional)
# - Fix Go toolchain policy for geoview: GOTOOLCHAIN=auto
# - First boot: musl loader symlink fix
# - First boot: dynamic procd guardian for config.apply behavior
# ============================================================

FILES_DIR="files"

mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"

# ------------------------------------------------------------
# 0) Build-time fix: Go toolchain policy for geoview
# ------------------------------------------------------------
echo "[patch] enabling Go toolchain auto-download (GOTOOLCHAIN=auto) ..."

GOLANG_PKG_MK="feeds/packages/lang/golang/golang-package.mk"
if [ -f "$GOLANG_PKG_MK" ]; then
  sed -i -E 's/\bGOTOOLCHAIN=local\b/GOTOOLCHAIN=auto/g' "$GOLANG_PKG_MK"
fi

GOLANG_BUILD_SH="feeds/packages/lang/golang/golang-build.sh"
if [ -f "$GOLANG_BUILD_SH" ]; then
  sed -i -E 's/\bGOTOOLCHAIN=local\b/GOTOOLCHAIN=auto/g' "$GOLANG_BUILD_SH"
fi

find feeds/packages/lang/golang -type f -print0 2>/dev/null | xargs -0 -r sed -i -E 's/\bGOTOOLCHAIN=[[:space:]]+auto\b/GOTOOLCHAIN=auto/g'

if grep -RInE '\bGOTOOLCHAIN=[[:space:]]+auto\b' feeds/packages/lang/golang >/dev/null 2>&1; then
  echo "ERROR: found 'GOTOOLCHAIN= auto' (with space). This will break builds." >&2
  grep -RInE '\bGOTOOLCHAIN=[[:space:]]+auto\b' feeds/packages/lang/golang | head -n 50 >&2 || true
  exit 1
fi

if grep -RInE '\bGOTOOLCHAIN=local\b' feeds/packages/lang/golang >/dev/null 2>&1; then
  echo "ERROR: still found 'GOTOOLCHAIN=local' after patch." >&2
  grep -RInE '\bGOTOOLCHAIN=local\b' feeds/packages/lang/golang | head -n 50 >&2 || true
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
# 6) First boot: musl loader symlink fix (runtime binary loader)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/90-musl-loader-fix" <<'EOF'
#!/bin/sh
set -eu
if [ ! -L /lib/ld-musl-x86_64.so.1 ] && [ -f /lib/libc.so ]; then
  ln -sf /lib/libc.so /lib/ld-musl-x86_64.so.1
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/90-musl-loader-fix"

# ------------------------------------------------------------
# 7) First boot: dynamic procd guardian (no build-time init.d files)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/99-harrywrt-guardian" <<'EOF'
#!/bin/sh
set -eu

cat > /etc/init.d/harrywrt_guardian <<'INNER'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

service_triggers() {
  procd_add_config_trigger "config.change" "firewall" /etc/init.d/harrywrt_guardian restart
  procd_add_config_trigger "config.change" "passwall2" /etc/init.d/harrywrt_guardian restart
}

start_service() {
  [ -x /etc/init.d/firewall ] && /etc/init.d/firewall reload >/dev/null 2>&1 || true
  sleep 2
  [ -x /etc/init.d/passwall2 ] && /etc/init.d/passwall2 restart >/dev/null 2>&1 || true
}
INNER

chmod 0755 /etc/init.d/harrywrt_guardian
/etc/init.d/harrywrt_guardian enable >/dev/null 2>&1 || true
/etc/init.d/harrywrt_guardian start  >/dev/null 2>&1 || true

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/99-harrywrt-guardian"

# ------------------------------------------------------------
# 8) Optional first boot kick for passwall2 (only if installed)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/98-passwall2-autofix" <<'EOF'
#!/bin/sh
if [ -x /etc/init.d/passwall2 ] && [ ! -f /etc/passwall2_init_done ]; then
  /etc/init.d/firewall restart >/dev/null 2>&1 || true
  sleep 2
  /etc/init.d/passwall2 restart >/dev/null 2>&1 || true
  touch /etc/passwall2_init_done
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/98-passwall2-autofix"

echo "DIY script executed successfully."
