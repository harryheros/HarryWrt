#!/usr/bin/env bash
set -euo pipefail

FILES_DIR="files"
mkdir -p "${FILES_DIR}/etc/config" "${FILES_DIR}/etc/uci-defaults" "${FILES_DIR}/etc/init.d"

# ------------------------------------------------------------
# 0) Build-time compatibility: Go toolchain policy (keep your proven regex)
# ------------------------------------------------------------
echo "[patch] enabling Go toolchain auto policy ..."
GOLANG_PKG_MK="feeds/packages/lang/golang/golang-package.mk"
GOLANG_BUILD_SH="feeds/packages/lang/golang/golang-build.sh"

[ -f "$GOLANG_PKG_MK" ] && sed -i -E 's/\bGOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local\b/GOTOOLCHAIN=auto/g' "$GOLANG_PKG_MK"
[ -f "$GOLANG_BUILD_SH" ] && sed -i -E 's/\bGOTOOLCHAIN[[:space:]]*:?=[[:space:]]*local\b/GOTOOLCHAIN=auto/g' "$GOLANG_BUILD_SH"

# clean accidental spaces: "GOTOOLCHAIN= auto" -> "GOTOOLCHAIN=auto"
find feeds/packages/lang/golang -type f -print0 2>/dev/null | xargs -0 -r sed -i -E 's/\bGOTOOLCHAIN=[[:space:]]+auto\b/GOTOOLCHAIN=auto/g'

echo "[patch] Go toolchain policy patched OK."

# ------------------------------------------------------------
# 1) System defaults (keep minimal)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/config/system" <<'EOF'
config system
  option hostname 'HarryWrt'
  option timezone 'HKT-8'
  option zonename 'Asia/Hong_Kong'
EOF

# ------------------------------------------------------------
# 2) Runtime Apply Helper (generic, not passwall2-specific in wording)
#    - On config changes: firewall/network/passwall2
#    - Do firewall reload first, then restart passwall2 if present
#    - Silent by default; avoids log spam when passwall2 not installed
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/init.d/harrywrt_apply_helper" <<'EOF'
#!/bin/sh /etc/rc.common

USE_PROCD=1
START=95

# Debounce to avoid rapid consecutive restarts during Save & Apply
DEBOUNCE_FILE="/tmp/harrywrt_apply_helper.last"
DEBOUNCE_SEC=3

debounce_ok() {
    local now last
    now="$(date +%s)"
    last="$(cat "$DEBOUNCE_FILE" 2>/dev/null || echo 0)"
    if [ $((now - last)) -lt "$DEBOUNCE_SEC" ]; then
        return 1
    fi
    echo "$now" > "$DEBOUNCE_FILE"
    return 0
}

run_apply() {
    # Always keep it quiet; return codes are not critical for UX
    [ -x /etc/init.d/firewall ] && /etc/init.d/firewall reload >/dev/null 2>&1 || true

    # Give fw4/nft a moment to settle (fast but helps)
    sleep 1

    # If user installed passwall2 later, kick it too
    if [ -x /etc/init.d/passwall2 ]; then
        /etc/init.d/passwall2 restart >/dev/null 2>&1 || true
    fi
}

service_triggers() {
    # Trigger on common config changes
    procd_add_config_trigger "config.change" "firewall" /etc/init.d/harrywrt_apply_helper restart
    procd_add_config_trigger "config.change" "network"  /etc/init.d/harrywrt_apply_helper restart
    procd_add_config_trigger "config.change" "passwall2" /etc/init.d/harrywrt_apply_helper restart
}

start_service() {
    procd_open_instance
    procd_set_param command /bin/sh -c '
        if '"$(. /lib/functions.sh 2>/dev/null; echo true)"'; then :; fi
        # one-shot apply helper
        if [ -f "'"$DEBOUNCE_FILE"'" ]; then :; fi
        exit 0
    '
    procd_set_param respawn 0 0 0
    procd_close_instance

    # Only do real work when restarted via triggers or init
    debounce_ok && run_apply || true
}
EOF
chmod 0755 "${FILES_DIR}/etc/init.d/harrywrt_apply_helper"

# ------------------------------------------------------------
# 3) Enable apply helper on first boot
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/30-harrywrt-apply-helper" <<'EOF'
#!/bin/sh
/etc/init.d/harrywrt_apply_helper enable >/dev/null 2>&1 || true
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/30-harrywrt-apply-helper"

# ------------------------------------------------------------
# 4) Musl loader compatibility (only if missing)
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/90-musl-ld-fix" <<'EOF'
#!/bin/sh
if [ ! -e /lib/ld-musl-x86_64.so.1 ] && [ -f /lib/libc.so ]; then
    ln -sf /lib/libc.so /lib/ld-musl-x86_64.so.1 >/dev/null 2>&1 || true
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/90-musl-ld-fix"

echo "DIY script executed successfully."
