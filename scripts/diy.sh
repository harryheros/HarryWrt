#!/usr/bin/env bash
set -euo pipefail

# =============================================================
# HarryWrt DIY Script (Multi-version / Multi-platform / Multi-profile)
#
# Usage: diy.sh <OWRT_VERSION> <TARGET> [PROFILE]
#   e.g. diy.sh 24.10.6 x86_64 clean
#        diy.sh 25.12.4 aarch64 plus
#
# - Branding (banner / motd / DISTRIB_DESCRIPTION)
# - Default LuCI theme forced to Bootstrap
# - Go toolchain GOTOOLCHAIN=auto patch (for geoview)
# - First boot: musl loader symlink fix (arch-aware)
# # - First boot: clean non-existent passwall_packages feed
# - First boot: patch LuCI package manager (apk trust + mirror auto-detect)
# - NTP configuration preserved
# - [plus only] UPnP disabled by default
# =============================================================

HARRYWRT_VER="${1:?Usage: diy.sh <OWRT_VERSION> <TARGET> [PROFILE]}"
TARGET="${2:?Usage: diy.sh <OWRT_VERSION> <TARGET> [PROFILE]}"
PROFILE="${3:-clean}"

# Guard: must be run from inside the openwrt source directory
if [[ ! -f "Makefile" ]] || ! grep -q "TOPDIR:=" Makefile 2>/dev/null; then
  echo "ERROR: diy.sh must be run from within the openwrt source directory (current: $PWD)" >&2
  exit 1
fi

FILES_DIR="files"
mkdir -p "${FILES_DIR}/etc/config"
mkdir -p "${FILES_DIR}/etc/uci-defaults"
mkdir -p "${FILES_DIR}/usr/libexec"

echo "============================================================"
echo " HarryWrt DIY: OpenWrt ${HARRYWRT_VER} / ${TARGET} / ${PROFILE}"
echo "============================================================"

# Derive human-readable edition label
case "${PROFILE}" in
  plus)  EDITION="Plus" ;;
  *)     EDITION="Clean" ;;
esac

# ------------------------------------------------------------
# 0a) 25.12+: replace luci-app-opkg with luci-app-package-manager
#     The config files use luci-app-opkg for compatibility with 24.10.
#     On 25.12+, opkg is replaced by apk; swap the package in .config.
# ------------------------------------------------------------
if [[ "${HARRYWRT_VER}" == 25.* ]]; then
  if [ -f ".config" ]; then
    sed -i 's/CONFIG_PACKAGE_luci-app-opkg=y/CONFIG_PACKAGE_luci-app-package-manager=y/' .config
    echo "[patch] 25.12: luci-app-opkg -> luci-app-package-manager"
  fi
fi

# ------------------------------------------------------------
# 0) Build-time fix: Go toolchain policy for geoview
#    GOTOOLCHAIN=local → auto (allows downloading newer Go)
# ------------------------------------------------------------
echo "[patch] Patching GOTOOLCHAIN=local -> auto in golang framework ..."

GOLANG_FRAMEWORK_FILES=(
  "feeds/packages/lang/golang/golang-package.mk"
  "feeds/packages/lang/golang/golang-build.sh"
)

for f in "${GOLANG_FRAMEWORK_FILES[@]}"; do
  if [ -f "$f" ]; then
    if grep -qE '\bGOTOOLCHAIN=local\b' "$f"; then
      sed -i -E 's/\bGOTOOLCHAIN=local\b/GOTOOLCHAIN=auto/g' "$f"
      echo "[patch] Framework patched: $f"
    else
      echo "[patch] No GOTOOLCHAIN=local in: $f (already auto or not set)"
    fi
  else
    echo "[patch] WARNING: framework file not found: $f" >&2
  fi
done

# Scan all .mk/.sh under golang lang dir
while IFS= read -r -d '' f; do
  if grep -qE '\bGOTOOLCHAIN=local\b' "$f"; then
    sed -i -E 's/\bGOTOOLCHAIN=local\b/GOTOOLCHAIN=auto/g' "$f"
    echo "[patch] Additional file patched: $f"
  fi
done < <(find feeds/packages/lang/golang -type f \( -name "*.mk" -o -name "*.sh" \) -print0 2>/dev/null)

# Double-insurance: inject into geoview Makefile
GEOVIEW_MK_CANDIDATES=(
  "feeds/passwall_packages/geoview/Makefile"
  "feeds/packages/net/geoview/Makefile"
)
for mk in "${GEOVIEW_MK_CANDIDATES[@]}"; do
  if [ -f "$mk" ]; then
    echo "[patch] Found geoview Makefile: $mk"
    if ! grep -qE '\bGOTOOLCHAIN\b' "$mk"; then
      sed -i '/^include.*golang-package/i export GOTOOLCHAIN=auto' "$mk"
      echo "[patch] Injected GOTOOLCHAIN=auto into: $mk"
    else
      sed -i -E 's/\bGOTOOLCHAIN=local\b/GOTOOLCHAIN=auto/g' "$mk"
      echo "[patch] Updated GOTOOLCHAIN in: $mk"
    fi
  fi
done

# Sanity check (warn only)
remaining=$(grep -RInE '\bGOTOOLCHAIN=local\b' feeds/packages/lang/golang 2>/dev/null || true)
if [[ -n "$remaining" ]]; then
  echo "[patch] WARNING: GOTOOLCHAIN=local still found:" >&2
  echo "$remaining" | head -n 10 >&2
else
  echo "[patch] Confirmed: no GOTOOLCHAIN=local remaining."
fi

# ------------------------------------------------------------
# 1) System defaults (hostname, timezone, NTP)
#    Note: cronloglevel=7 is required for 25.12+
# ------------------------------------------------------------
CRONLOGLEVEL=5
if [[ "${HARRYWRT_VER}" == 25.* ]]; then
  CRONLOGLEVEL=7
fi

cat > "${FILES_DIR}/etc/config/system" <<EOF
config system
  option hostname 'HarryWrt'
  option timezone 'HKT-8'
  option zonename 'Asia/Hong_Kong'
  option ttylogin '0'
  option log_proto 'stderr'
  option conloglevel '8'
  option cronloglevel '${CRONLOGLEVEL}'

config timeserver 'ntp'
  option enabled '1'
  option enable_server '0'
  list server '0.openwrt.pool.ntp.org'
  list server '1.openwrt.pool.ntp.org'
  list server '2.openwrt.pool.ntp.org'
  list server '3.openwrt.pool.ntp.org'
EOF

# ------------------------------------------------------------
# 2) SSH login banner
# ------------------------------------------------------------
if [[ "${PROFILE}" == "plus" ]]; then
  PLUS_BANNER_LINE=" Plus extras: UPnP available, disabled by default"
else
  PLUS_BANNER_LINE=""
fi

cat > "${FILES_DIR}/etc/banner" <<EOF
---------------------------------------------------------------
 _   _                          __        __     _
| | | | __ _ _ __ _ __ _   _   \ \      / /_ __| |_
| |_| |/ _\` | '__| '__| | | |   \ \ /\ / / '__| __|
|  _  | (_| | |  | |  | |_| |    \ V  V /| |  | |_
|_| |_|\__,_|_|  |_|   \__, |     \_/\_/ |_|   \__|
                        |___/
---------------------------------------------------------------
 HarryWrt ${HARRYWRT_VER} | ${EDITION} Edition | ${TARGET}
 Based on OpenWrt | No Bloatware | Performance Focused
---------------------------------------------------------------
${PLUS_BANNER_LINE}
EOF

# ------------------------------------------------------------
# 3) MOTD
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/motd" <<EOF
HarryWrt ${HARRYWRT_VER} - ${EDITION} Edition (based on OpenWrt) [${TARGET}]
EOF

# ------------------------------------------------------------
# 4) UCI defaults: branding
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding" <<EOF
#!/bin/sh
DESC="HarryWrt ${HARRYWRT_VER} ${EDITION} (based on OpenWrt)"

if [ -f /etc/openwrt_release ]; then
  sed -i "s/^DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION='\${DESC}'/" /etc/openwrt_release 2>/dev/null || true
fi
if [ -f /etc/os-release ]; then
  sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"\${DESC}\"/" /etc/os-release 2>/dev/null || true
fi
if [ -f /usr/lib/os-release ]; then
  sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"\${DESC}\"/" /usr/lib/os-release 2>/dev/null || true
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding"

# ------------------------------------------------------------
# 5) Force LuCI default theme to Bootstrap
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/50-force-default-theme" <<'EOF'
#!/bin/sh
if command -v uci >/dev/null 2>&1; then
  uci -q set luci.main.mediaurlbase='/luci-static/bootstrap' || true
  uci -q commit luci || true
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/50-force-default-theme"

# ------------------------------------------------------------
# 5b) DHCP and dnsmasq sensible defaults
#     - DHCP start from .10 (leave .2-.9 for static devices)
#     - sequential IP assignment (like every commercial router)
#     - dnsmasq cache 150 -> 1000 for better DNS performance
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/uci-defaults/51-harrywrt-dhcp-defaults" <<'EOF'
#!/bin/sh
# DHCP: start from .10, sequential, larger cache
uci -q set dhcp.lan.start='10'
uci -q set dhcp.lan.limit='240'
uci -q set dhcp.lan.sequential_ip='1'
uci -q set dhcp.@dnsmasq[0].cachesize='1000'
uci -q commit dhcp
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/51-harrywrt-dhcp-defaults"

# ------------------------------------------------------------
# 6) First boot: musl loader symlink fix (arch-aware)
# ------------------------------------------------------------
case "${TARGET}" in
  x86_64)   MUSL_LOADER="ld-musl-x86_64.so.1" ;;
  aarch64)  MUSL_LOADER="ld-musl-aarch64.so.1" ;;
  *)        MUSL_LOADER="" ;;
esac

if [[ -n "${MUSL_LOADER}" ]]; then
cat > "${FILES_DIR}/etc/uci-defaults/90-musl-loader-fix" <<EOF
#!/bin/sh
if [ ! -L /lib/${MUSL_LOADER} ] && [ -f /lib/libc.so ]; then
  ln -sf /lib/libc.so /lib/${MUSL_LOADER}
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/90-musl-loader-fix"
fi

# ------------------------------------------------------------
# 7) Guardian removed from Clean/Plus
#
#    The old harrywrt_guardian could silently restart passwall2
#    after firewall/passwall2 config changes. That kind of hidden
#    automation is useful only in a lab/full profile, not in daily
#    Clean/Plus firmware.
# ------------------------------------------------------------

# ------------------------------------------------------------
# 8) First boot: clean non-existent passwall_packages feed
#
#    The passwall_packages feed is added at build time to
#    compile dependencies, but the URL gets baked into the
#    firmware's apk/opkg repository config. Since OpenWrt's
#    official download server doesn't host this feed, apk
#    will fail when refreshing repos (even for local installs).
#    This script removes the phantom feed entry on first boot.
# ------------------------------------------------------------
if [[ "${HARRYWRT_VER}" == 25.* ]]; then
cat > "${FILES_DIR}/etc/uci-defaults/91-clean-passwall-feed" <<'EOF'
#!/bin/sh
# Remove passwall_packages feed — does not exist on official repos
for f in /etc/apk/repositories.d/*.list; do
  [ -f "$f" ] || continue
  sed -i '/passwall_packages/d' "$f"
done
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/91-clean-passwall-feed"
else
cat > "${FILES_DIR}/etc/uci-defaults/91-clean-passwall-feed" <<'EOF'
#!/bin/sh
# Remove passwall_packages feed — does not exist on official repos
if [ -f /etc/opkg/distfeeds.conf ]; then
  sed -i '/passwall_packages/d' /etc/opkg/distfeeds.conf
fi
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/91-clean-passwall-feed"
fi

# ------------------------------------------------------------
# 9) First boot: replace LuCI package manager for local .apk
#    install (25.12+ only) and install mirror auto-detect helper
#
#    OpenWrt 25.12 switched from opkg to apk (Alpine Package
#    Keeper). Unlike opkg, apk enforces signature verification
#    on ALL packages — including local uploads via LuCI. This
#    breaks the "upload .apk → install" workflow that users
#    expect from 24.10's seamless .ipk experience.
#
#    Strategy: replace /usr/libexec/package-manager-call entirely
#    with a known-good wrapper rather than patching with sed
#    (the upstream script is compressed into a few long lines,
#    making sed append unreliable regardless of pattern accuracy).
#    The wrapper handles:
#      1) --allow-untrusted for local .apk file installs
#      2) mirror auto-detect via harrywrt-mirror-check before update
#      3) preserves the JSON output format LuCI expects
# ------------------------------------------------------------

# harrywrt-mirror-check: shared helper used by both 25.12 wrapper and 24.10 uci-default
mkdir -p "${FILES_DIR}/usr/bin"
if [[ "${HARRYWRT_VER}" == 25.* ]]; then
cat > "${FILES_DIR}/usr/bin/harrywrt-mirror-check" <<'EOF'
#!/bin/sh
# HarryWrt: auto-detect and switch apk mirror (25.12)
OFFICIAL="downloads.openwrt.org"
MIRROR="mirrors.tuna.tsinghua.edu.cn/openwrt"
if wget -q -O /dev/null --timeout=3 "https://${OFFICIAL}" 2>/dev/null; then
	for f in /etc/apk/repositories.d/*.list; do
		[ -f "$f" ] || continue
		sed -i "s|${MIRROR}|${OFFICIAL}|g" "$f"
	done
else
	for f in /etc/apk/repositories.d/*.list; do
		[ -f "$f" ] || continue
		sed -i "s|${OFFICIAL}|${MIRROR}|g" "$f"
	done
fi
EOF
chmod 0755 "${FILES_DIR}/usr/bin/harrywrt-mirror-check"
fi

if [[ "${HARRYWRT_VER}" == 25.* ]]; then
cat > "${FILES_DIR}/etc/uci-defaults/92-patch-package-manager" <<'PATCHEOF'
#!/bin/sh
# HarryWrt: replace package-manager-call with a known-good wrapper.
#
# Rationale: the upstream script is packed into a small number of long lines,
# making sed-based patching unreliable regardless of pattern accuracy.
# We back up the original and overwrite with a full self-contained script that:
#   1. Allows local .apk installs without signature checks (--allow-untrusted)
#   2. Runs a mirror connectivity check before every "update"
#   3. Preserves the JSON output format LuCI expects
#   4. Remains compatible with both apk (25.12) and opkg (fallback)

PMC="/usr/libexec/package-manager-call"
[ -x "$PMC" ] || exit 0

# Only patch once
grep -q 'harrywrt' "$PMC" && exit 0

cp -f "$PMC" "$PMC.harrywrt.bak"

cat > "$PMC" <<'EOF'
#!/bin/sh
# HarryWrt managed package-manager-call (25.12/apk)
. /usr/share/libubox/jshn.sh

action="$1"
shift

if [ -x /usr/bin/apk ]; then
	ipkg_bin="apk"
else
	ipkg_bin="opkg"
fi

_harrywrt_mirror_check() {
	[ -x /usr/bin/harrywrt-mirror-check ] && /usr/bin/harrywrt-mirror-check >/dev/null 2>&1
	return 0
}

_harrywrt_has_local_apk() {
	for p in "$@"; do
		case "$p" in
			/*.apk|./*.apk|../*.apk|*.apk)
				[ -f "$p" ] && return 0
			;;
		esac
	done
	return 1
}

case "$action" in
list-installed)
	if [ "$ipkg_bin" = "apk" ]; then
		$ipkg_bin query --fields all --format json --installed --from system \* 2>/dev/null
	else
		cat /usr/lib/opkg/status
	fi
;;
list-available)
	if [ "$ipkg_bin" = "apk" ]; then
		$ipkg_bin query --fields all --format json --available \* 2>/dev/null
	else
		lists_dir="$(sed -rne 's#^lists_dir \S+ (\S+)#\1#p' /etc/opkg.conf /etc/opkg/*.conf 2>/dev/null | tail -n 1)"
		find "${lists_dir:-/usr/lib/opkg/lists}" -type f '!' -name '*.sig' | xargs -r gzip -cd
	fi
;;
install|update|upgrade|remove)
	(
		cmd="$ipkg_bin"

		if [ "$action" = "update" ]; then
			_harrywrt_mirror_check
		fi

		if [ "$ipkg_bin" = "apk" ]; then
			case "$action" in
				install)
					action="add"
					if _harrywrt_has_local_apk "$@"; then
						cmd="$cmd --allow-untrusted"
					fi
				;;
				remove)
					action="del"
				;;
			esac
		fi

		if [ "$ipkg_bin" = "apk" ]; then
			while [ -n "$1" ]; do
				case "$1" in
					--autoremove)
						shift
					;;
					--force-removal-of-dependent-packages)
						cmd="$cmd -r"
						shift
					;;
					--force-overwrite)
						cmd="$cmd $1"
						shift
					;;
					-*)
						shift
					;;
					*)
						break
					;;
				esac
			done
		else
			while [ -n "$1" ]; do
				case "$1" in
					--autoremove|--force-overwrite|--force-removal-of-dependent-packages)
						cmd="$cmd $1"
						shift
					;;
					-*)
						shift
					;;
					*)
						break
					;;
				esac
			done
		fi

		if flock -x 200; then
			pkmcmd="$cmd $action $*"
			$cmd "$action" "$@" >/tmp/ipkg.out 2>/tmp/ipkg.err
			code=$?
			stdout="$(cat /tmp/ipkg.out)"
			stderr="$(cat /tmp/ipkg.err)"
		else
			code=255
			stderr="Failed to acquire lock"
		fi

		json_init
		json_add_int code "$code"
		[ -n "$pkmcmd" ] && json_add_string pkmcmd "$pkmcmd"
		[ -n "$stdout" ] && json_add_string stdout "$stdout"
		[ -n "$stderr" ] && json_add_string stderr "$stderr"
		json_dump
	) 200>/tmp/ipkg.lock
	rm -f /tmp/ipkg.lock /tmp/ipkg.err /tmp/ipkg.out
;;
*)
	echo "Usage: $0 {list-installed|list-available|update}" >&2
	echo "       $0 {install|upgrade|remove} pkg[ pkg...]" >&2
	exit 1
;;
esac
EOF

chmod 0755 "$PMC"

# Verify patch integrity — hard fail if either hook is missing
grep -q -- '--allow-untrusted' "$PMC" || {
	echo "HarryWrt package-manager patch failed: missing --allow-untrusted" >&2
	cp -f "$PMC.harrywrt.bak" "$PMC"
	exit 1
}
grep -q '_harrywrt_mirror_check' "$PMC" || {
	echo "HarryWrt package-manager patch failed: missing mirror check" >&2
	cp -f "$PMC.harrywrt.bak" "$PMC"
	exit 1
}

exit 0
PATCHEOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/92-patch-package-manager"
else
# 24.10 (opkg): mirror auto-detect at first boot.
# Rather than patching package-manager-call with sed (unreliable against compressed lines),
# we write a standalone mirror-check script and call it from the update uci-default directly.
# The mirror state is written to distfeeds.conf; subsequent opkg update calls pick it up.
cat > "${FILES_DIR}/etc/uci-defaults/92-patch-package-manager" <<'PATCHEOF'
#!/bin/sh
# HarryWrt: install mirror auto-detect helper for opkg (24.10)
# Called by /usr/bin/harrywrt-mirror-check before opkg update

MIRROR_SCRIPT="/usr/bin/harrywrt-mirror-check"
[ -f "$MIRROR_SCRIPT" ] && exit 0

cat > "$MIRROR_SCRIPT" <<'EOF'
#!/bin/sh
OFFICIAL="downloads.openwrt.org"
MIRROR="mirrors.tuna.tsinghua.edu.cn/openwrt"
CONF="/etc/opkg/distfeeds.conf"
[ -f "$CONF" ] || exit 0
if wget -q -O /dev/null --timeout=3 "https://${OFFICIAL}" 2>/dev/null; then
	sed -i "s|${MIRROR}|${OFFICIAL}|g" "$CONF"
else
	sed -i "s|${OFFICIAL}|${MIRROR}|g" "$CONF"
fi
EOF
chmod 0755 "$MIRROR_SCRIPT"

# Run once on first boot to set the correct mirror immediately
"$MIRROR_SCRIPT" || true

exit 0
PATCHEOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/92-patch-package-manager"
fi

# ------------------------------------------------------------
# 10) Plus-only safe defaults and feature manager
#
#     Plus keeps optional network-facing services disabled by default.
#     The feature manager currently manages only UPnP, avoiding DNS,
#     routing, or firewall takeover logic.
# ------------------------------------------------------------
if [[ "${PROFILE}" == "plus" ]]; then

cat > "${FILES_DIR}/usr/libexec/harrywrt-feature-manager" <<'EOF'
#!/bin/sh
set -u

log() { echo "[harrywrt] $*"; }
err() { echo "[harrywrt] ERROR: $*" >&2; }
has_init() { [ -x "/etc/init.d/$1" ]; }

stop_disable() {
  local svc="$1"
  has_init "$svc" || return 0
  /etc/init.d/$svc stop >/dev/null 2>&1 || true
  /etc/init.d/$svc disable >/dev/null 2>&1 || true
}

enable_start() {
  local svc="$1"
  has_init "$svc" || { err "service not installed: $svc"; return 1; }
  /etc/init.d/$svc enable >/dev/null 2>&1 || true
  /etc/init.d/$svc start >/dev/null 2>&1 || /etc/init.d/$svc restart >/dev/null 2>&1 || return 1
}

upnp_enable() {
  uci -q set upnpd.config.enabled='1' 2>/dev/null || true
  uci -q commit upnpd 2>/dev/null || true
  enable_start miniupnpd && log "UPnP enabled"
}

upnp_disable() {
  uci -q set upnpd.config.enabled='0' 2>/dev/null || true
  uci -q commit upnpd 2>/dev/null || true
  stop_disable miniupnpd
  log "UPnP disabled"
}

status_one() {
  local svc="$1"
  if has_init "$svc"; then
    if /etc/init.d/$svc enabled >/dev/null 2>&1; then
      echo "$svc: enabled"
    else
      echo "$svc: disabled"
    fi
  else
    echo "$svc: not installed"
  fi
}

status_all() {
  status_one miniupnpd
  echo "dnsmasq.port=$(uci -q get dhcp.@dnsmasq[0].port 2>/dev/null || echo 53)"
  echo "dnsmasq.noresolv=$(uci -q get dhcp.@dnsmasq[0].noresolv 2>/dev/null || echo unset)"
}

usage() {
  cat <<USAGE
Usage:
  harrywrt-feature-manager status all
  harrywrt-feature-manager enable upnp
  harrywrt-feature-manager disable upnp
USAGE
}

action="${1:-}"; feature="${2:-all}"
case "$action:$feature" in
  enable:upnp) upnp_enable ;;
  disable:upnp) upnp_disable ;;
  status:*|:*) status_all ;;
  *) usage; exit 1 ;;
esac
EOF
chmod 0755 "${FILES_DIR}/usr/libexec/harrywrt-feature-manager"

cat > "${FILES_DIR}/etc/uci-defaults/60-harrywrt-plus-safe-defaults" <<'EOF'
#!/bin/sh
# Plus safe defaults:
# - UPnP is installed but disabled.
# - dnsmasq remains the default stable DNS/DHCP service on first boot.

[ -x /usr/libexec/harrywrt-feature-manager ] && ln -sf /usr/libexec/harrywrt-feature-manager /usr/bin/harrywrt-feature-manager

uci -q delete dhcp.@dnsmasq[0].port >/dev/null 2>&1 || true
uci -q set dhcp.@dnsmasq[0].noresolv='0'
uci -q commit dhcp 2>/dev/null || true

# Disable optional services on first boot.
for svc in miniupnpd; do
  [ -x /etc/init.d/$svc ] || continue
  /etc/init.d/$svc stop >/dev/null 2>&1 || true
  /etc/init.d/$svc disable >/dev/null 2>&1 || true
done

uci -q set upnpd.config.enabled='0' 2>/dev/null || true
uci -q commit upnpd 2>/dev/null || true

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/60-harrywrt-plus-safe-defaults"

fi

echo "DIY script executed successfully for OpenWrt ${HARRYWRT_VER} / ${TARGET} / ${PROFILE}."
