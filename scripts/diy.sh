#!/usr/bin/env bash
set -euo pipefail

FILES_DIR="files"
mkdir -p "${FILES_DIR}/etc/config" "${FILES_DIR}/etc/uci-defaults" "${FILES_DIR}/etc/init.d"

# ------------------------------------------------------------
# 0) Build-time: Go toolchain policy patch (keep your regex)
# ------------------------------------------------------------
echo "[patch] enabling Go toolchain auto policy ..."
GOLANG_PKG_MK="feeds/packages/lang/golang/golang-package.mk"
GOLANG_BUILD_SH="feeds/packages/lang/golang/golang-build.sh"
[ -f "$GOLANG_PKG_MK" ] && sed -i -E 's/\bGOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local\b/GOTOOLCHAIN=auto/g' "$GOLANG_PKG_MK"
[ -f "$GOLANG_BUILD_SH" ] && sed -i -E 's/\bGOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local\b/GOTOOLCHAIN=auto/g' "$GOLANG_BUILD_SH"

# ------------------------------------------------------------
# 1) Procd service: harrywrt_guardian (config-change restart)
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
    [ -x /etc/init.d/firewall ] && /etc/init.d/firewall reload
    sleep 2
    [ -x /etc/init.d/passwall2 ] && /etc/init.d/passwall2 restart
}
EOF
chmod 0755 "${FILES_DIR}/etc/init.d/harrywrt_guardian"

# ------------------------------------------------------------
# 2) First boot init: musl loader link + enable guardian
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/99-harrywrt-init" <<'EOF'
#!/bin/sh
if [ ! -L /lib/ld-musl-x86_64.so.1 ] && [ -f /lib/libc.so ]; then
    ln -sf /lib/libc.so /lib/ld-musl-x86_64.so.1
fi
/etc/init.d/harrywrt_guardian enable
/etc/init.d/harrywrt_guardian start
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/99-harrywrt-init"

echo "DIY script executed successfully."
