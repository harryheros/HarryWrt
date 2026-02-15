#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# HarryWrt DIY Script (OpenWrt 24.10.5 / Clean)
# - Branding (banner/motd/DISTRIB_DESCRIPTION)
# - Keep stock-like LuCI look: Bootstrap as default theme
# - Build compatibility: Go toolchain policy patch (GOTOOLCHAIN=auto)
# - Runtime guardian: auto apply-kick after Save&Apply for firewall/passwall2
# - Musl linker fix: ensure binaries don't hit '-ash: not found'
# ============================================================

FILES_DIR="files"
mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"
mkdir -p "${FILES_DIR}/etc/init.d"

# ------------------------------------------------------------
# 0) Build-time compatibility: Go toolchain policy
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

# Clean accidental "GOTOOLCHAIN= auto"
find feeds/packages/lang/golang -type f -print0 2>/dev/null | xargs -0 -r sed -i -E 's/\bGOTOOLCHAIN=[[:space:]]+auto\b/GOTOOLCHAIN=auto/g'

# Fail fast if still bad
if grep -RInE '\bGOTOOLCHAIN=[[:space:]]+auto\b' feeds/packages/lang/golang >/dev/null 2>&1; then
  echo "ERROR: found 'GOTOOLCHAIN= auto' (with space)." >&2
  exit 1
fi
if grep -RInE '\bGOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local\b' feeds/packages/lang/golang >/dev/null 2>&1; then
  echo "ERROR: still found GOTOOLCHAIN=local after patch." >&2
  exit 1
fi

echo "[patch] Go toolchain policy patched OK."

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
# 4) Branding: release description
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
# 6) HarryWrt Runtime Guardian (procd)
#    - Watches UCI changes (firewall/passwall2)
#    - Ensures firewall reload happens before passwall2 restart
#    - Avoids referencing passwall2 when not installed (no log spam)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/init.d/harrywrt_guardian" <<'EOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

service_triggers() {
  procd_add_config_trigger "config.change" "firewall" /etc/init.d/harrywrt_guardian restart
  procd_add_config_trigger "config.change" "passwall2" /etc/init.d/harrywrt_guardian restart
}

start_service() {
  (
    # Small debounce to avoid rapid-fire restarts from multiple Save&Apply
    sleep 1

    [ -x /etc/init.d/firewall ] && /etc/init.d/firewall reload >/dev/null 2>&1 || true
    sleep 2

    if [ -x /etc/init.d/passwall2 ]; then
      /etc/init.d/passwall2 restart >/dev/null 2>&1 || true
    fi
  ) &
}
EOF
chmod 0755 "${FILES_DIR}/etc/init.d/harrywrt_guardian"

# ------------------------------------------------------------
# 7) First-boot init: musl linker fix + enable guardian
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/99-harrywrt-init" <<'EOF'
#!/bin/sh
# musl loader symlink (helps some third-party binaries on x86_64)
if [ ! -L /lib/ld-musl-x86_64.so.1 ] && [ -f /lib/libc.so ]; then
  ln -sf /lib/libc.so /lib/ld-musl-x86_64.so.1
fi

# enable runtime guardian
if [ -x /etc/init.d/harrywrt_guardian ]; then
  /etc/init.d/harrywrt_guardian enable >/dev/null 2>&1 || true
  /etc/init.d/harrywrt_guardian start  >/dev/null 2>&1 || true
fi

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/99-harrywrt-init"

echo "DIY script executed successfully."
