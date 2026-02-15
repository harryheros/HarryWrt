# ============================================================
# HarryWrt DIY Script (OpenWrt 24.10.5 / Clean)
# - Branding (banner/motd/DISTRIB_DESCRIPTION)
# - Keep stock-like LuCI look: Bootstrap as default theme
# - Build compatibility: Go toolchain policy patch (GOTOOLCHAIN=auto)
# - Runtime compatibility helpers (apply helper / first-boot kick)
# ============================================================

FILES_DIR="files"
mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"

# ------------------------------------------------------------
# 0) Build-time compatibility: Go toolchain policy
#    - Match both '=' and ':=' (defense-grade)
#    - Ensure "GOTOOLCHAIN=auto" has NO SPACE
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

# Fail fast: any remaining local / spaced-auto is unacceptable
if grep -RInE '\bGOTOOLCHAIN=[[:space:]]+auto\b' feeds/packages/lang/golang >/dev/null 2>&1; then
  echo "ERROR: found 'GOTOOLCHAIN= auto' (space after '='). This will break builds." >&2
  grep -RInE '\bGOTOOLCHAIN=[[:space:]]+auto\b' feeds/packages/lang/golang | head -n 50 >&2 || true
  exit 1
fi

if grep -RInE '\bGOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local\b' feeds/packages/lang/golang >/dev/null 2>&1; then
  echo "ERROR: still found GOTOOLCHAIN=local after patch." >&2
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
 HarryWrt 24.10.5 | Clean Edition | Stable Base
 Based on OpenWrt | Minimal | Performance Focused
---------------------------------------------------------------
EOF

# ------------------------------------------------------------
# 3) MOTD
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/motd" <<'EOF'
HarryWrt 24.10.5 - Clean Edition (based on OpenWrt)
EOF

# ------------------------------------------------------------
# 4) UCI defaults: branding
#    - Add || true to avoid noisy logs if file layout differs
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
# 6) Apply-helper (ucitrack linkage)
#    - Keep it minimal: only "firewall" and "dhcp"
#    - Avoid log spam for services that may not exist
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/30-ucitrack-apply-helper" <<'EOF'
#!/bin/sh
set -eu

[ -f /etc/config/ucitrack ] || touch /etc/config/ucitrack

# Keep helper minimal & safe
uci -q set ucitrack.apply_helper='config' || true
uci -q set ucitrack.apply_helper.init='firewall dhcp' || true
uci -q set ucitrack.apply_helper.affects='firewall dhcp' || true
uci -q commit ucitrack || true

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/30-ucitrack-apply-helper"

# ------------------------------------------------------------
# 7) First-boot compatibility kick
#    - musl loader symlink guard (x86_64)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/98-firstboot-apply-kick" <<'EOF'
#!/bin/sh
set -eu

# Prevent rare "-ash: not found" on certain prebuilt binaries
if [ ! -L /lib/ld-musl-x86_64.so.1 ] && [ -f /lib/libc.so ]; then
  ln -sf /lib/libc.so /lib/ld-musl-x86_64.so.1
fi

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/98-firstboot-apply-kick"

echo "DIY script executed successfully."
