# HarryWrt — OpenWrt-Based Firmware

[![License](https://img.shields.io/badge/license-GPLv2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![Platform](https://img.shields.io/badge/platform-x86__64%20%7C%20aarch64-orange.svg)](#)
[![Base](https://img.shields.io/badge/base-OpenWrt%2024.10.7%20%7C%2025.12.4-green.svg)](#)

HarryWrt is a stable, extensible OpenWrt-based firmware available in two profiles: **Clean** for minimalism and upstream compatibility, and **Plus** for users who want a full-featured primary router experience out of the box.

No bloat, no lock-in, no surprises — just a predictable and maintainable OpenWrt experience.

---

## Profiles

### Clean Edition
Minimal base system for users who want full control over what runs on their router.

- Clean base system — no unnecessary modifications
- Fully compatible with upstream OpenWrt packages
- No bundled proxy engines — a truly minimal base; add what you need yourself
- Built-in WAN/DNS/IPv6 health check dashboard

### Plus Edition
Stable enhanced firmware. Everything in Clean, plus:

- WireGuard VPN, DDNS, UPnP / NAT-PMP, traffic monitoring (nlbwmon), Wake-on-LAN, network diagnostics
- ACME / Let's Encrypt certificate management
- Bundled proxy engines (xray-core, sing-box) and geo data, offline-ready for users who install a proxy LuCI app
- UPnP disabled by default; all other components ready to configure on first boot
- See [Included Components](#included-components) for full package list


---

## Firmware Matrix

| OpenWrt | Profile | Platform | rootfs | Package Manager | Status |
|---------|---------|----------|--------|-----------------|--------|
| 24.10.7 | Clean   | x86_64   | 768MB  | opkg            | LTS (EOL Sep 2026) |
| 24.10.7 | Clean   | aarch64  | 512MB  | opkg            | LTS (EOL Sep 2026) |
| 25.12.4 | Clean   | x86_64   | 768MB  | apk             | Current Stable |
| 25.12.4 | Clean   | aarch64  | 512MB  | apk             | Current Stable |
| 24.10.7 | Plus    | x86_64   | 1024MB | opkg            | LTS (EOL Sep 2026) |
| 24.10.7 | Plus    | aarch64  | 768MB  | opkg            | LTS (EOL Sep 2026) |
| 25.12.4 | Plus    | x86_64   | 1024MB | apk             | Current Stable |
| 25.12.4 | Plus    | aarch64  | 768MB  | apk             | Current Stable |

### Which profile should I choose?

**Clean** — If you want full control, plan to install only what you need, or are deploying in a server/VM environment where minimal footprint matters.

**Plus** — If you want a primary home router with WireGuard VPN, DDNS, UPnP, and traffic monitoring ready to configure out of the box.

### Which OpenWrt version should I choose?

**24.10.7** — If you have an existing opkg-based setup with many installed packages and want a stable, familiar upgrade path. Will receive security fixes until September 2026.

**25.12.4** — Recommended for new installations. Uses the new apk package manager (replaces opkg). Better performance and latest security patches.

### Which platform?

**x86_64** — For soft routers, PCs, virtual machines (Proxmox/ESXi/QEMU), industrial mini-PCs. On first boot, HarryWrt automatically expands the overlay partition to fill the available disk space.

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

### Network Health
Built-in WAN/DNS/IPv6 health check dashboard (Status → Network Health). Refreshes every 5 minutes, available on all profiles.

### Themes
Default: Bootstrap (official). Optional: Argon (included, not enabled by default)

### System Tools
bash, curl, wget-ssl, unzip, htop, openssl-util, ca-bundle

### Network Utilities
ip-full, iperf3, tcpdump, ethtool, resolveip

### Firewall / Kernel
nftables (fw4), iptables-nft compatibility layer, kmod-tun, TProxy modules (nft + ipt), nft-socket, nft-nat

### Proxy Engines (Plus edition only)
The **Plus** edition bundles, offline-ready: xray-core, sing-box, geoview, v2ray-geoip, v2ray-geosite, tcping and their runtime libs. The **Clean** edition does not include these — install them yourself if needed. On either edition, a proxy LuCI app (if desired) is installed separately after first boot.

### Plus Edition — Additional Components

| Component | Package(s) | Notes |
|-----------|-----------|-------|
| WireGuard VPN | kmod-wireguard, wireguard-tools, luci-app-wireguard, qrencode | QR code peer export supported |
| DDNS | ddns-scripts, luci-app-ddns, ddns-scripts-cloudflare, ddns-scripts-noip | Requires configuration to activate |
| UPnP / NAT-PMP | miniupnpd-nftables, luci-app-upnp | Disabled by default; enable via feature manager |
| Traffic monitoring | nlbwmon, luci-app-nlbwmon | Per-device bandwidth tracking |
| Wake-on-LAN | etherwake, luci-app-wol | |
| Network diagnostics | mtr-json | |
| ACME / Let's Encrypt | acme, luci-app-acme | Certificate management for HTTPS services |

---

## Default Settings

- Hostname: HarryWrt
- Timezone: UTC
- LAN IP: 192.168.1.1
- User: root
- Password: unset on first boot
- NTP: enabled (0-3.openwrt.pool.ntp.org)

---

## First Access

After boot, connect via LAN (DHCP enabled) and open https://192.168.1.1

Set a password on first login before further configuration.

> Browser SSL warnings are expected (self-signed certificate).


### HarryWrt Feature Manager

Plus Edition keeps UPnP disabled by default. Use the feature manager to enable or disable it:

```sh
harrywrt-feature-manager status all
harrywrt-feature-manager enable upnp
harrywrt-feature-manager disable upnp
```


---

## Upgrading

1. Download the new `.img.gz` from the [Releases page](https://github.com/harryheros/harrywrt/releases)
2. LuCI → System → Backup / Flash Firmware → Flash new firmware
3. Upload the `.img.gz` file
4. Choose whether to keep settings:
   - **Same OpenWrt version** (e.g. HarryWrt v3.0 → v3.1) — keeping settings is safe
   - **Different OpenWrt version** (e.g. 24.10 → 25.12) — do not keep settings; config format may have changed
5. Wait for reboot

> After upgrading, manually re-install any packages you had added (AdGuard Home, Passwall2, etc.). Pre-installed HarryWrt packages are unaffected.

---

## Installing a Proxy LuCI App

On the **Plus** edition, the required dependencies (xray-core, sing-box, geoview, v2ray-geoip, v2ray-geosite, tcping, etc.) are already pre-installed, so you only need to install the LuCI app itself. On the **Clean** edition, install those dependencies yourself first (or use the Plus edition).

### On OpenWrt 24.10.7 (opkg)

1. Download `luci-app-passwall2_VERSION_all.ipk` from [Passwall2 Releases](https://github.com/Openwrt-Passwall/openwrt-passwall2/releases)
2. In LuCI: System → Software → Upload Package → select the `.ipk` file → Install
3. Refresh browser, Passwall2 appears under Services menu

### On OpenWrt 25.12.4 (apk)

1. Download `luci-app-passwall2_VERSION_all.apk` from [Passwall2 Releases](https://github.com/Openwrt-Passwall/openwrt-passwall2/releases)
2. In LuCI: System → Software → Upload Package → select the `.apk` file → Install
3. Refresh browser, Passwall2 appears under Services menu

> **Note:** HarryWrt 25.12.4 includes a patched LuCI package manager that allows local `.apk` uploads without signature verification errors. The install experience is identical to 24.10.7 — upload and install directly from the web UI, no SSH required.

> **Important:** On 25.12.4, make sure to download the `.apk` format (not `.ipk`). The `.ipk` format is only compatible with 24.10.x.

### Mirror auto-detection

HarryWrt includes a built-in mirror auto-detection helper (`harrywrt-mirror-check`). On first boot, and on every package list update on 25.12.4, HarryWrt tests connectivity to `downloads.openwrt.org`. If the official server is unreachable, it automatically switches the repository configuration to the TUNA mirror (`mirrors.tuna.tsinghua.edu.cn/openwrt`) and restores the official server when it becomes reachable again.

This runs transparently; no manual configuration is needed.

If you need to switch or restore manually:

```sh
# Let the helper auto-detect and set the correct source (both versions)
/usr/bin/harrywrt-mirror-check

# Switch to TUNA mirror manually — OpenWrt 25.12 (apk)
sed -i 's_downloads.openwrt.org_mirrors.tuna.tsinghua.edu.cn/openwrt_g' /etc/apk/repositories.d/distfeeds.list

# Restore official source — OpenWrt 25.12 (apk)
sed -i 's_mirrors.tuna.tsinghua.edu.cn/openwrt_downloads.openwrt.org_g' /etc/apk/repositories.d/distfeeds.list

# Switch to TUNA mirror manually — OpenWrt 24.10 (opkg)
sed -i 's_downloads.openwrt.org_mirrors.tuna.tsinghua.edu.cn/openwrt_g' /etc/opkg/distfeeds.conf

# Restore official source — OpenWrt 24.10 (opkg)
sed -i 's_mirrors.tuna.tsinghua.edu.cn/openwrt_downloads.openwrt.org_g' /etc/opkg/distfeeds.conf
```

---

## Installing AdGuard Home

AdGuard Home is not pre-installed in HarryWrt. Install it directly from the package repository when needed.

### On OpenWrt 25.12.4 (apk)

```sh
apk update && apk add adguardhome
```

### On OpenWrt 24.10.7 (opkg)

```sh
opkg update && opkg install adguardhome
```

### After installation

AdGuard Home and dnsmasq both try to bind port 53. You need to move dnsmasq off port 53 before starting AdGuard Home, or they will conflict:

```sh
# Move dnsmasq to port 5353 (keeps DHCP and local DNS working)
uci set dhcp.@dnsmasq[0].port='5353'
uci commit dhcp
/etc/init.d/dnsmasq restart

# Start AdGuard Home
/etc/init.d/adguardhome enable
/etc/init.d/adguardhome start
```

Then open `http://192.168.1.1:3000` to complete the AdGuard Home setup wizard.

> If something goes wrong, restore dnsmasq to port 53 with:
> ```sh
> uci delete dhcp.@dnsmasq[0].port
> uci commit dhcp
> /etc/init.d/dnsmasq restart
> /etc/init.d/adguardhome stop
> /etc/init.d/adguardhome disable
> ```

---

## Customization

HarryWrt remains fully compatible with upstream OpenWrt. Install additional packages via LuCI (Web UI) or the command line (opkg on 24.10 / apk on 25.12).

### Enable Argon Theme

LuCI → System → System → Language and Style → Theme → Argon

---

## Integrity Verification

Each release includes SHA256 checksum files. Download the checksum file and the `.img.gz` into the same directory, then verify:

```sh
# Example: 25.12.4 Plus x86_64
cd ~/Downloads
sha256sum -c SHA256SUMS-25.12.4-plus-x86_64

# Other variants follow the same pattern
sha256sum -c SHA256SUMS-24.10.7-clean-x86_64
sha256sum -c SHA256SUMS-24.10.7-plus-x86_64
sha256sum -c SHA256SUMS-25.12.4-clean-x86_64
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
- AdGuard Home (AdGuard)

---

## Author

Maintained by: harryheros

---

Part of the [Nova infrastructure toolkit](https://github.com/harryheros).