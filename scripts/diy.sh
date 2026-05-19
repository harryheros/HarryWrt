#!/usr/bin/env bash
set -euo pipefail

# =============================================================
# HarryWrt DIY Script (Multi-version / Multi-platform / Multi-profile)
#
# Usage: diy.sh <OWRT_VERSION> <TARGET> [PROFILE] [REL]
#   e.g. diy.sh 24.10.6 x86_64 clean v3.1
#        diy.sh 25.12.4 aarch64 plus v3.1
#
# - Branding (banner / motd / DISTRIB_DESCRIPTION)
# - Default LuCI theme forced to Bootstrap
# - Go toolchain GOTOOLCHAIN=auto patch (for geoview)
# - First boot: musl loader symlink fix (arch-aware)
# - First boot: clean non-existent passwall_packages feed
# - First boot: patch LuCI package manager (apk trust + mirror auto-detect)
# - NTP configuration preserved
# - [plus only] UPnP disabled by default
# =============================================================

HARRYWRT_VER="${1:?Usage: diy.sh <OWRT_VERSION> <TARGET> [PROFILE] [REL]}"
TARGET="${2:?Usage: diy.sh <OWRT_VERSION> <TARGET> [PROFILE] [REL]}"
PROFILE="${3:-clean}"
HARRYWRT_REL="${4:-}"

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
  option timezone 'UTC'
  option zonename 'UTC'
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

BANNER_VER="${HARRYWRT_REL:-${HARRYWRT_VER}}"
cat > "${FILES_DIR}/etc/banner" <<EOF
---------------------------------------------------------------
 _   _                          __        __     _
| | | | __ _ _ __ _ __ _   _   \ \      / /_ __| |_
| |_| |/ _\` | '__| '__| | | |   \ \ /\ / / '__| __|
|  _  | (_| | |  | |  | |_| |    \ V  V /| |  | |_
|_| |_|\__,_|_|  |_|   \__, |     \_/\_/ |_|   \__|
                        |___/
---------------------------------------------------------------
 HarryWrt ${BANNER_VER} | ${EDITION} Edition | ${TARGET}
 Based on OpenWrt | No Bloatware | Performance Focused
---------------------------------------------------------------
${PLUS_BANNER_LINE}
EOF

# ------------------------------------------------------------
# 3) MOTD
# ------------------------------------------------------------
cat > "${FILES_DIR}/etc/motd" <<EOF
HarryWrt ${BANNER_VER} - ${EDITION} Edition (based on OpenWrt) [${TARGET}]
EOF

# ------------------------------------------------------------
# 4) Branding — write directly into files/ at build time.
#    LuCI reads /rom/etc/openwrt_release (the squashfs layer),
#    so we must place the correct values there at build time,
#    not via a uci-default that only runs on overlay.
# ------------------------------------------------------------
if [[ -n "${HARRYWRT_REL}" ]]; then
  DESC="HarryWrt ${HARRYWRT_REL} ${EDITION} (OpenWrt ${HARRYWRT_VER})"
  REVISION="HarryWrt ${HARRYWRT_REL}"
else
  DESC="HarryWrt ${HARRYWRT_VER} ${EDITION} (based on OpenWrt)"
  REVISION="HarryWrt"
fi

mkdir -p "${FILES_DIR}/etc"
cat > "${FILES_DIR}/etc/openwrt_release" <<EOF
DISTRIB_ID='OpenWrt'
DISTRIB_RELEASE='${HARRYWRT_VER}'
DISTRIB_REVISION='${REVISION}'
DISTRIB_CODENAME='HarryWrt'
DISTRIB_TARGET=''
DISTRIB_ARCH=''
DISTRIB_DESCRIPTION='${DESC}'
DISTRIB_TAINTS=''
EOF

# uci-default fills in DISTRIB_TARGET and DISTRIB_ARCH at runtime
cat > "${FILES_DIR}/etc/uci-defaults/10-harrywrt-branding" <<'BRANDEOF'
#!/bin/sh
RELEASE_FILE="/etc/openwrt_release"
[ -f "$RELEASE_FILE" ] || exit 0
ARCH="$(uname -m 2>/dev/null || echo '')"
TARGET="$(cat /tmp/sysinfo/board_name 2>/dev/null || echo '')"
[ -n "$ARCH" ] && sed -i "s/^DISTRIB_ARCH=.*/DISTRIB_ARCH='${ARCH}'/" "$RELEASE_FILE" || true
[ -n "$TARGET" ] && sed -i "s/^DISTRIB_TARGET=.*/DISTRIB_TARGET='${TARGET}'/" "$RELEASE_FILE" || true
exit 0
BRANDEOF
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

# harrywrt-mirror-check: pre-installed for both 25.12 (apk) and 24.10 (opkg)
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
else
cat > "${FILES_DIR}/usr/bin/harrywrt-mirror-check" <<'EOF'
#!/bin/sh
# HarryWrt: auto-detect and switch opkg mirror (24.10)
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
fi
chmod 0755 "${FILES_DIR}/usr/bin/harrywrt-mirror-check"

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
						cmd="$cmd --allow-untrusted --no-network"
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
# Plus safe defaults: UPnP installed but disabled on first boot.

[ -x /usr/libexec/harrywrt-feature-manager ] && ln -sf /usr/libexec/harrywrt-feature-manager /usr/bin/harrywrt-feature-manager

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

# ------------------------------------------------------------
# 11) WAN/DNS health check (all profiles, all platforms)
#
#     Lightweight network diagnostics accessible from LuCI.
#     Tests: WAN reachability, DNS resolution, IPv6 connectivity.
#     Results cached every 5 minutes via cron, instant on page load.
# ------------------------------------------------------------
mkdir -p "${FILES_DIR}/usr/bin"
mkdir -p "${FILES_DIR}/www/cgi-bin"
mkdir -p "${FILES_DIR}/etc/cron.d"
mkdir -p "${FILES_DIR}/usr/share/luci/menu.d"
mkdir -p "${FILES_DIR}/www/luci-static/resources/view/harrywrt"

cat > "${FILES_DIR}/usr/bin/harrywrt-health-check" <<'EOF'
#!/bin/sh
# HarryWrt network health check
# Outputs JSON to stdout or writes to /tmp/harrywrt-health.json if called with --cache

CACHE_FILE="/tmp/harrywrt-health.json"
TS="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

check_wan() {
    if wget -q -O /dev/null --timeout=5 "http://connectivitycheck.gstatic.com/generate_204" 2>/dev/null; then
        echo "ok"
    elif wget -q -O /dev/null --timeout=5 "http://www.msftconnecttest.com/connecttest.txt" 2>/dev/null; then
        echo "ok"
    else
        echo "fail"
    fi
}

check_dns() {
    if nslookup openwrt.org >/dev/null 2>&1; then
        echo "ok"
    else
        echo "fail"
    fi
}

check_ipv6() {
    if ping6 -c 1 -W 3 2606:4700:4700::1111 >/dev/null 2>&1; then
        echo "ok"
    else
        echo "fail"
    fi
}

check_wan_ip() {
    ip route get 1.1.1.1 2>/dev/null | grep -o 'src [0-9.]*' | awk '{print $2}' || echo ""
}

WAN_STATUS="$(check_wan)"
DNS_STATUS="$(check_dns)"
IPV6_STATUS="$(check_ipv6)"
WAN_IP="$(check_wan_ip)"

JSON="$(printf '{"timestamp":"%s","wan":"%s","dns":"%s","ipv6":"%s","wan_ip":"%s"}' "$TS" "$WAN_STATUS" "$DNS_STATUS" "$IPV6_STATUS" "$WAN_IP")"

if [ "${1:-}" = "--cache" ]; then
    echo "$JSON" > "$CACHE_FILE"
else
    echo "$JSON"
fi
EOF
chmod 0755 "${FILES_DIR}/usr/bin/harrywrt-health-check"

# CGI endpoint - serves cached result instantly, or runs check if cache is stale
cat > "${FILES_DIR}/www/cgi-bin/harrywrt-health" <<'EOF'
#!/bin/sh
CACHE="/tmp/harrywrt-health.json"
echo "Content-Type: application/json"
echo "Cache-Control: no-cache"
echo ""
if [ -f "$CACHE" ] && [ "$(( $(date +%s) - $(date +%s -r "$CACHE" 2>/dev/null || echo 0) ))" -lt 360 ]; then
    cat "$CACHE"
else
    /usr/bin/harrywrt-health-check --cache
    cat "$CACHE"
fi
EOF
chmod 0755 "${FILES_DIR}/www/cgi-bin/harrywrt-health"

# Cron job - refresh cache every 5 minutes
cat > "${FILES_DIR}/etc/cron.d/harrywrt-health" <<'EOF'
*/5 * * * * root /usr/bin/harrywrt-health-check --cache
EOF

# LuCI menu entry
cat > "${FILES_DIR}/usr/share/luci/menu.d/harrywrt-health.json" <<'EOF'
{
  "admin/status/harrywrt-health": {
    "title": "Network Health",
    "order": 5,
    "action": {
      "type": "view",
      "path": "harrywrt/health"
    }
  }
}
EOF

# LuCI JS view
cat > "${FILES_DIR}/www/luci-static/resources/view/harrywrt/health.js" <<'EOF'
'use strict';
'require view';
'require poll';

return view.extend({
    render: function() {
        var container = E('div', { 'style': 'padding:1em;max-width:600px;' }, [
            E('h2', {}, 'Network Health'),
            E('div', { 'id': 'harrywrt-health-status' }, [
                E('p', { 'style': 'color:#888;' }, 'Checking...')
            ])
        ]);
        return container;
    },

    pollData: function() {
        return fetch('/cgi-bin/harrywrt-health')
            .then(function(r) { return r.json(); })
            .then(function(d) {
                var el = document.getElementById('harrywrt-health-status');
                if (!el) return;

                function badge(status) {
                    var ok = status === 'ok';
                    return E('span', {
                        'style': 'display:inline-block;padding:2px 10px;border-radius:3px;font-weight:bold;color:#fff;background:' + (ok ? '#5cb85c' : '#d9534f') + ';margin-left:8px;'
                    }, ok ? 'Online' : 'Offline');
                }

                function row(label, status, extra) {
                    return E('div', { 'style': 'display:flex;align-items:center;padding:10px 0;border-bottom:1px solid #eee;' }, [
                        E('span', { 'style': 'width:140px;font-weight:bold;' }, label),
                        badge(status),
                        extra ? E('span', { 'style': 'margin-left:12px;color:#666;font-size:0.9em;' }, extra) : null
                    ].filter(Boolean));
                }

                var ts = d.timestamp ? new Date(d.timestamp).toLocaleTimeString() : '';

                el.innerHTML = '';
                el.appendChild(row('WAN', d.wan, d.wan_ip || ''));
                el.appendChild(row('DNS', d.dns, ''));
                el.appendChild(row('IPv6', d.ipv6, ''));
                if (ts) {
                    el.appendChild(E('p', { 'style': 'margin-top:12px;color:#aaa;font-size:0.85em;' }, 'Last checked: ' + ts));
                }

                var refreshBtn = E('button', {
                    'style': 'margin-top:1em;padding:6px 16px;background:#367fa9;color:#fff;border:none;border-radius:4px;cursor:pointer;',
                    'onclick': function() {
                        el.innerHTML = '<p style="color:#888;">Checking...</p>';
                        fetch('/cgi-bin/harrywrt-health?refresh=1')
                            .then(function(r) { return r.json(); })
                            .then(function(d2) {
                                // re-render by re-polling
                            });
                    }
                }, 'Refresh Now');
                el.appendChild(refreshBtn);
            })
            .catch(function() {
                var el = document.getElementById('harrywrt-health-status');
                if (el) el.innerHTML = '<p style="color:#d9534f;">Failed to fetch health status.</p>';
            });
    },

    load: function() {
        return this.pollData();
    },

    handleSaveApply: null,
    handleSave: null,
    handleReset: null
});
EOF

# ------------------------------------------------------------
# 12) RootFS auto-expand (x86_64 only)
#
#     When the firmware image is written to a disk larger than
#     the image itself, the remaining space is unallocated.
#     This script detects unallocated space > 512MB after the
#     last partition and expands the overlay partition to fill it.
#     Requires: parted, resize2fs (e2fsprogs)
#     Safe: exits immediately if conditions are not met.
# ------------------------------------------------------------
if [[ "${TARGET}" == "x86_64" ]]; then

cat > "${FILES_DIR}/etc/uci-defaults/95-rootfs-expand" <<'EOF'
#!/bin/sh
# HarryWrt: auto-expand overlay partition if disk has unallocated space
# Runs once on first boot, exits safely if conditions not met

command -v parted >/dev/null 2>&1 || exit 0
command -v resize2fs >/dev/null 2>&1 || exit 0

# Find the root disk (the disk containing the root filesystem)
ROOT_DEV="$(findfs / 2>/dev/null || true)"
[ -z "$ROOT_DEV" ] && exit 0

# Get the disk device (strip partition number)
DISK="$(echo "$ROOT_DEV" | sed 's/[0-9]*$//;s/p$//')"
[ -b "$DISK" ] || exit 0

# Find the overlay partition (last partition on disk)
OVERLAY_PART="$(parted -s "$DISK" print 2>/dev/null | awk '/^ +[0-9]/ {last=$1} END {print last}')"
[ -z "$OVERLAY_PART" ] && exit 0

# Get disk size and last partition end in MB
DISK_SIZE_MB="$(parted -s "$DISK" unit MB print 2>/dev/null | grep "^Disk $DISK" | grep -o '[0-9]*MB' | tr -d 'MB')"
PART_END_MB="$(parted -s "$DISK" unit MB print 2>/dev/null | awk "/^ +${OVERLAY_PART} / {gsub(/MB/,"",$3); print $3}")"

[ -z "$DISK_SIZE_MB" ] || [ -z "$PART_END_MB" ] && exit 0

UNALLOCATED=$(( DISK_SIZE_MB - PART_END_MB ))

# Only expand if more than 512MB unallocated
[ "$UNALLOCATED" -lt 512 ] && exit 0

logger -t harrywrt "Auto-expanding overlay partition: ${UNALLOCATED}MB available"

# Expand partition to fill disk
parted -s "$DISK" resizepart "$OVERLAY_PART" 100% || exit 0

# Inform kernel of partition change
partprobe "$DISK" 2>/dev/null || true
sleep 2

# Determine overlay partition device
if echo "$DISK" | grep -q 'nvme\|mmcblk'; then
    OVERLAY_DEV="${DISK}p${OVERLAY_PART}"
else
    OVERLAY_DEV="${DISK}${OVERLAY_PART}"
fi

[ -b "$OVERLAY_DEV" ] || exit 0

# Resize filesystem
resize2fs "$OVERLAY_DEV" && logger -t harrywrt "Overlay partition expanded successfully" || true

exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/95-rootfs-expand"

fi

# ------------------------------------------------------------
# 13) ACME / Let's Encrypt (Plus only)
# ------------------------------------------------------------
if [[ "${PROFILE}" == "plus" ]]; then

cat > "${FILES_DIR}/etc/uci-defaults/65-harrywrt-acme-defaults" <<'EOF'
#!/bin/sh
# ACME is installed but not configured by default.
# Configure via LuCI: Services -> ACME Certificates
exit 0
EOF
chmod 0755 "${FILES_DIR}/etc/uci-defaults/65-harrywrt-acme-defaults"

fi

# ------------------------------------------------------------
# HarryWrt version widget in LuCI Status page
# Uses LuCI's official status/include mechanism — zero side effects.
# File 05_harrywrt.js loads before 10_system.js (system info).
# Reads DISTRIB_DESCRIPTION from /etc/openwrt_release via CGI.
# ------------------------------------------------------------
mkdir -p "${FILES_DIR}/www/luci-static/resources/view/status/include"

cat > "${FILES_DIR}/www/luci-static/resources/view/status/include/05_harrywrt.js" <<'EOF'
'use strict';
'require baseclass';
'require fs';

return baseclass.extend({
    title: _('HarryWrt'),

    load: function() {
        return fs.lines('/etc/openwrt_release').catch(function() { return []; });
    },

    render: function(lines) {
        var desc = '';
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/^DISTRIB_DESCRIPTION='?([^']+)'?/);
            if (m) { desc = m[1]; break; }
        }
        if (!desc) return null;

        return E('table', { 'class': 'table' }, [
            E('tr', { 'class': 'tr table-titles' }, [
                E('th', { 'class': 'th', 'colspan': '2', 'style': 'background:#367fa9;color:#fff;padding:6px 10px;font-size:1em;' }, desc)
            ])
        ]);
    }
});
EOF

echo "DIY script executed successfully for OpenWrt ${HARRYWRT_VER} / ${TARGET} / ${PROFILE}."
