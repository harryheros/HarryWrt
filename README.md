# HarryWrt — OpenWrt-Based Firmware

[![License](https://img.shields.io/badge/license-GPLv2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![Platform](https://img.shields.io/badge/platform-x86__64%20%7C%20aarch64-orange.svg)](#)
[![Base](https://img.shields.io/badge/base-OpenWrt%2024.10.6%20%7C%2025.12.4-green.svg)](#)

HarryWrt is a stable, extensible OpenWrt-based firmware available in two profiles: **Clean** for minimalism and upstream compatibility, and **Plus** for users who want a full-featured primary router experience out of the box.

No bloat, no lock-in, no surprises — just a predictable and maintainable OpenWrt experience.

---

## Profiles

### Clean Edition
Minimal base system for users who want full control over what runs on their router.

- Clean base system — no unnecessary modifications
- Fully compatible with upstream OpenWrt packages
- Pre-installed Passwall2 dependencies for offline setup
- Modern firewall stack (nftables / fw4)

### Plus Edition
Stable enhanced firmware. Everything in Clean, plus pre-installed tools that stay inert until explicitly enabled:

- WireGuard VPN — kernel module + LuCI UI + QR code export
- DDNS — Cloudflare and No-IP scripts with LuCI management
- UPnP / NAT-PMP — miniupnpd-nftables, disabled by default; enable with `harrywrt-feature-manager enable upnp`
- Traffic monitoring — nlbwmon per-device bandwidth tracking
- Wake-on-LAN
- Network diagnostics — mtr-json

---

## Shared Features

- Dual OpenWrt version support (24.10.6 LTS + 25.12.4 stable)
- Dual platform support (x86_64 + aarch64 ARM64)
- Modern firewall stack (nftables / fw4)
- Built and released automatically via GitHub Actions

---

## Firmware Matrix

| OpenWrt | Profile | Platform | rootfs | Package Manager | Status |
|---------|---------|----------|--------|-----------------|--------|
| 24.10.6 | Clean   | x86_64   | 768MB  | opkg            | LTS (EOL Sep 2026) |
| 24.10.6 | Clean   | aarch64  | 512MB  | opkg            | LTS (EOL Sep 2026) |
| 25.12.4 | Clean   | x86_64   | 768MB  | apk             | Current Stable |
| 25.12.4 | Clean   | aarch64  | 512MB  | apk             | Current Stable |
| 24.10.6 | Plus    | x86_64   | 1024MB | opkg            | LTS (EOL Sep 2026) |
| 24.10.6 | Plus    | aarch64  | 768MB  | opkg            | LTS (EOL Sep 2026) |
| 25.12.4 | Plus    | x86_64   | 1024MB | apk             | Current Stable |
| 25.12.4 | Plus    | aarch64  | 768MB  | apk             | Current Stable |

### Which profile should I choose?

**Clean** — If you want full control, plan to install only what you need, or are deploying in a server/VM environment where minimal footprint matters.


### Which OpenWrt version should I choose?

**24.10.6** — If you have an existing opkg-based setup with many installed packages and want a stable, familiar upgrade path. Will receive security fixes until September 2026.

**25.12.4** — Recommended for new installations. Uses the new apk package manager (replaces opkg). Better performance and latest security patches.

### Which platform?

**x86_64** — For soft routers, PCs, virtual machines (Proxmox/ESXi/QEMU), industrial mini-PCs.

**aarch64 (armsr/armv8)** — Generic ARM64 UEFI image. Works with NanoPi R4S/R5S/R6S, Raspberry Pi 4/5, and other ARM64 devices that support UEFI boot. Note: NanoPi R2S uses arm32 and is not compatible with this image. For device-specific optimizations, consider using dedicated target images.

---

## Downloads

Firmware images are available on the GitHub Releases page:

https://github.com/harryheros/harrywrt/releases

Each release includes BIOS and UEFI images (x86_64), squashfs and ext4 variants, and SHA256 checksum files.

### Recommended Images

| Use Case | File |
|----------|------|
| Modern x86 PC / VM (UEFI) — Clean | `*-clean-*-x86_64-squashfs-uefi.img.gz` |
| Modern x86 PC / VM (UEFI) — Plus  | `*-plus-*-x86_64-squashfs-uefi.img.gz` |
| Legacy x86 PC (BIOS) — Clean      | `*-clean-*-x86_64-squashfs-bios.img.gz` |
| Legacy x86 PC (BIOS) — Plus       | `*-plus-*-x86_64-squashfs-bios.img.gz` |
| ARM64 devices — Clean             | `*-clean-*-aarch64-squashfs-*.img.gz` |
| ARM64 devices — Plus              | `*-plus-*-aarch64-squashfs-*.img.gz` |

---

## Included Components

### Web Interface
LuCI (HTTPS), luci-compat, ttyd (Web Terminal)

### Themes
Default: Bootstrap (official). Optional: Argon (included, not enabled by default)

### System Tools
bash, curl, wget-ssl, unzip, htop, openssl-util, ca-bundle

### Network Utilities
ip-full, iperf3, tcpdump, ethtool, resolveip

### Firewall / Kernel
nftables (fw4), iptables-nft compatibility layer, kmod-tun, TProxy modules (nft + ipt), nft-socket, nft-nat

### Passwall2 Ready
Pre-installed dependencies: xray-core, sing-box, geoview, v2ray-geoip, v2ray-geosite, tcping, coreutils, libev, libsodium, libudns. Install passwall2 itself via package manager or manual upload after first boot.

### Plus Edition — Additional Components

| Component | Package(s) | Notes |
|-----------|-----------|-------|
| WireGuard VPN | kmod-wireguard, wireguard-tools, luci-app-wireguard, qrencode | QR code peer export supported |
| DDNS | ddns-scripts, luci-app-ddns, ddns-scripts-cloudflare, ddns-scripts-noip | Disabled by default |
| UPnP / NAT-PMP | miniupnpd-nftables, luci-app-upnp | Disabled by default; enable via feature manager |
| Traffic monitoring | nlbwmon, luci-app-nlbwmon | Per-device bandwidth tracking |
| Wake-on-LAN | etherwake, luci-app-wol | |
| Network diagnostics | mtr-json | |

---

## Default Settings

- Hostname: HarryWrt
- Timezone: Asia/Hong_Kong
- LAN IP: 192.168.1.1
- User: root
- Password: unset on first boot
- NTP: enabled (pool.ntp.org)

---

## First Access

After boot, connect via LAN (DHCP enabled) and open https://192.168.1.1

Set a password on first login before further configuration.

> Browser SSL warnings are expected (self-signed certificate).


### HarryWrt Feature Manager

Plus Edition keeps network-takeover features disabled by default. Use the feature manager to enable them with service restart, DNS health check, and rollback:

```sh
harrywrt-feature-manager status all
harrywrt-feature-manager enable upnp
```


```sh
harrywrt-feature-manager enable doh
```



When enabled, HarryWrt will:

1. back up `/etc/config/dhcp`;
2. move dnsmasq from port 53 to port 5353;
4. use Cloudflare and Quad9 DoH as default upstreams;
5. run a DNS health check;
6. roll back automatically if DNS fails.

After enabling, open:

```text
http://router.lan:3000
http://192.168.1.1:3000
```

Default upstreams:

- `https://1.1.1.1/dns-query`
- `https://9.9.9.9/dns-query`

### Removed from Plus mainline

The following components are intentionally no longer included in Plus because they frequently modify routing, firewall rules, or background service state and are better suited for a separate Full/Lab profile:

- `https-dns-proxy`
- `mwan3`
- `banip`
- `collectd` / `luci-app-statistics`
- `harrywrt_guardian`

Plus should be a daily-use firmware: more convenient than Clean, but not more fragile.

---

## Installing Passwall2

All required dependencies (xray-core, sing-box, geoview, v2ray-geoip, v2ray-geosite, tcping, etc.) are already pre-installed in HarryWrt. You only need to install the Passwall2 LuCI app itself.

### On OpenWrt 24.10.6 (opkg)

1. Download `luci-app-passwall2_VERSION_all.ipk` from [Passwall2 Releases](https://github.com/Openwrt-Passwall/openwrt-passwall2/releases)
2. In LuCI: System → Software → Upload Package → select the `.ipk` file → Install
3. Refresh browser, Passwall2 appears under Services menu

### On OpenWrt 25.12.4 (apk)

1. Download `luci-app-passwall2_VERSION_all.apk` from [Passwall2 Releases](https://github.com/Openwrt-Passwall/openwrt-passwall2/releases)
2. In LuCI: System → Software → Upload Package → select the `.apk` file → Install
3. Refresh browser, Passwall2 appears under Services menu

> **Note:** HarryWrt 25.12.4 includes a patched LuCI package manager that allows local `.apk` uploads without signature verification errors. The install experience is identical to 24.10.6 — upload and install directly from the web UI, no SSH required.

> **Important:** On 25.12.4, make sure to download the `.apk` format (not `.ipk`). The `.ipk` format is only compatible with 24.10.x.

### Mirror auto-detection

HarryWrt includes a built-in mirror auto-detection helper (`harrywrt-mirror-check`). On first boot, and on every package list update on 25.12.4, HarryWrt tests connectivity to `downloads.openwrt.org`. If the official server is unreachable, it automatically switches the repository configuration to the TUNA mirror (`mirrors.tuna.tsinghua.edu.cn/openwrt`) and restores the official server when it becomes reachable again.

This runs transparently; no manual configuration is needed.

If you need to switch manually:

```sh
# Run the helper directly (both versions)
/usr/bin/harrywrt-mirror-check

# Or set manually — OpenWrt 25.12 (apk)
sed -i 's_downloads.openwrt.org_mirrors.tuna.tsinghua.edu.cn/openwrt_g' /etc/apk/repositories.d/distfeeds.list

# OpenWrt 24.10 (opkg)
sed -i 's_downloads.openwrt.org_mirrors.tuna.tsinghua.edu.cn/openwrt_g' /etc/opkg/distfeeds.conf
```

---

## Customization

HarryWrt remains fully compatible with upstream OpenWrt. Install additional packages via LuCI (Web UI) or the command line (opkg on 24.10 / apk on 25.12).

### Enable Argon Theme

LuCI → System → System → Language and Style → Theme → Argon

---

## Integrity Verification

Each release includes SHA256 checksum files. Always verify downloaded images before use:

```sh
# 24.10.6 Clean
sha256sum -c SHA256SUMS-24.10.6-clean-x86_64

# 24.10.6 Plus
sha256sum -c SHA256SUMS-24.10.6-plus-x86_64

# 25.12.4 Clean
sha256sum -c SHA256SUMS-25.12.4-clean-x86_64

# 25.12.4 Plus
sha256sum -c SHA256SUMS-25.12.4-plus-x86_64
```

---

## Disclaimer

HarryWrt is provided as-is without warranty. This firmware contains no telemetry, hidden services, or proprietary components. Users are responsible for their own deployments and configurations.

---

## License

HarryWrt follows the OpenWrt licensing model and is distributed under GPL-2.0.

All modifications and distributed binaries comply with upstream OpenWrt licensing requirements.

---

## Credits

- OpenWrt Project
- LuCI Project
- Argon Theme (jerrykuku)
- Passwall2 (Openwrt-Passwall Organization)

---

## Author

Maintained by: harryheros

---

Part of the [Nova infrastructure toolkit](https://github.com/harryheros).