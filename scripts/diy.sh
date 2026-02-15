#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# HarryWrt DIY Script (OpenWrt 24.10.5 / Clean)
# - Branding (banner/motd/DISTRIB_DESCRIPTION)
# - Default LuCI theme forced to Bootstrap (Argon remains optional)
# - Fix Go toolchain policy for geoview (Go >= 1.24): GOTOOLCHAIN=auto
# - Defense-grade regex for Go toolchain patching (= or :=)
# - HarryWrt Runtime Guardian (Auto-fix Cores & Loader)
# ============================================================

FILES_DIR="files"

mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"
mkdir -p "${FILES_DIR}/etc/init.d"

# ------------------------------------------------------------
# 0) Build-time fix: Go toolchain policy for geoview
# ------------------------------------------------------------
echo "[patch] enabling Go toolchain auto-download (GOTOOLCHAIN=auto) ..."

GOLANG_PKG_MK="feeds/packages/lang/golang/golang-package.mk"
GOLANG_BUILD_SH="feeds/packages/lang/golang/golang-build.sh"

if [ -f "$GOLANG_PKG_MK" ]; then
  sed -i -E 's/\bGOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local\b/GOTOOLCHAIN=auto/g' "$GOLANG_PKG_MK"
fi

if [ -f "$GOLANG_BUILD_SH" ]; then
  sed -i -E 's/\bGOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local\b/GOTOOLCHAIN=auto/g' "$GOLANG_BUILD_SH"
fi

find feeds/packages/lang/golang -type f -print0 2>/dev/null | xargs -0 -r sed -i -E 's/\bGOTOOLCHAIN=[[:space:]]+auto\b/GOTOOLCHAIN=auto/g'

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
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding"

# ------------------------------------------------------------
# 5) Force LuCI default theme to Bootstrap
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
# 6) HarryWrt Runtime Guardian
#    - Fixes musl loader for Xray/Sing-box (-ash: not found)
#    - Ensures network services (Passwall2) start correctly
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/init.d/harrywrt_guardian" <<'EOF'
#!/bin/sh /etc/rc.common

START=99

boot() {
    (
        # Fix dynamic linker path (resolve -ash: not found error)
        if [ ! -L /lib/ld-musl-x86_64.so.1 ] && [ -f /lib/libc.so ]; then
            ln -sf /lib/libc.so /lib/ld-musl-x86_64.so.1
        fi

        # Set execution permissions
        chmod 755 /usr/bin/xray /usr/bin/sing-box 2>/dev/null || true

        # Wait for network and firewall to stabilize
        sleep 20
        
        # Force restart passwall2 if exists to ensure rules apply
        if [ -x /etc/init.d/passwall2 ]; then
            /etc/init.d/passwall2 restart >/dev/null 2>&1
        fi
    ) &
}

start() {
    boot
}
EOF
chmod 0755 "${FILES_DIR}/etc/init.d/harrywrt_guardian"

# Enable guardian service via uci-defaults
cat > "${FILES_DIR}/etc/uci-defaults/98-harrywrt-guardian-setup" <<'EOF'
#!/bin/sh
/etc/init.d/harrywrt_guardian enable
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/98-harrywrt-guardian-setup"

echo "DIY script executed successfully."
