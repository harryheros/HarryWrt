#!/usr/bin/env bash
set -euo pipefail

FILES_DIR="files"
mkdir -p "${FILES_DIR}/etc/uci-defaults"
mkdir -p "${FILES_DIR}/lib"

# ------------------------------------------------------------
# 0) Build-time compatibility: Go toolchain policy
# ------------------------------------------------------------
GOLANG_PKG_MK="feeds/packages/lang/golang/golang-package.mk"
GOLANG_BUILD_SH="feeds/packages/lang/golang/golang-build.sh"

if [ -f "$GOLANG_PKG_MK" ]; then
  sed -i -E 's/\bGOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local\b/GOTOOLCHAIN=auto/g' "$GOLANG_PKG_MK"
fi

if [ -f "$GOLANG_BUILD_SH" ]; then
  sed -i -E 's/\bGOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local\b/GOTOOLCHAIN=auto/g' "$GOLANG_BUILD_SH"
fi

# ------------------------------------------------------------
# 0.5) Rootfs-time fix: ensure musl loader link exists early
# ------------------------------------------------------------
if [ ! -L "${FILES_DIR}/lib/ld-musl-x86_64.so.1" ]; then
  ln -sf libc.so "${FILES_DIR}/lib/ld-musl-x86_64.so.1"
fi

# ------------------------------------------------------------
# 1) First boot setup: generate guardian dynamically
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/99-harrywrt-setup" <<'EOF'
#!/bin/sh
set -eu

# Create guardian service file on first boot
mkdir -p /etc/init.d

cat > /etc/init.d/harrywrt_guardian <<'INNER'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

service_triggers() {
  procd_add_config_trigger "config.change" "firewall" /etc/init.d/harrywrt_guardian restart
  procd_add_config_trigger "config.change" "passwall2" /etc/init.d/harrywrt_guardian restart
}

start_service() {
  [ -x /etc/init.d/firewall ] && /etc/init.d/firewall reload || true
  sleep 2
  [ -x /etc/init.d/passwall2 ] && /etc/init.d/passwall2 restart || true
}
INNER

chmod 0755 /etc/init.d/harrywrt_guardian || true

# System identity
uci -q set system.@system[0].hostname='HarryWrt' || true
uci -q set system.@system[0].timezone='HKT-8' || true
uci -q set system.@system[0].zonename='Asia/Hong_Kong' || true
uci -q commit system || true

# Banner
{
  echo "---------------------------------------------------------------"
  echo " HarryWrt 24.10.5 | Clean Edition "
  echo "---------------------------------------------------------------"
} > /etc/banner 2>/dev/null || true

# Runtime musl safety
if [ ! -L /lib/ld-musl-x86_64.so.1 ] && [ -f /lib/libc.so ]; then
  ln -sf /lib/libc.so /lib/ld-musl-x86_64.so.1 || true
fi

# Enable guardian
/etc/init.d/harrywrt_guardian enable >/dev/null 2>&1 || true
/etc/init.d/harrywrt_guardian start  >/dev/null 2>&1 || true

exit 0
EOF

chmod 0755 "${FILES_DIR}/etc/uci-defaults/99-harrywrt-setup"

echo "DIY script executed successfully."
