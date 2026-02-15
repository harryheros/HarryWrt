# HarryWrt

[![License: GPL v2](https://img.shields.io/badge/License-GPLv2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![Platform](https://img.shields.io/badge/Platform-BIOS%20%7C%20UEFI-orange.svg)](#)

**HarryWrt** is a clean and stable OpenWrt firmware build, focused on reliability, performance, and long-term usability.

Built on official **OpenWrt 24.10.5** sources, HarryWrt is designed for users who want a minimal but powerful base system with practical built-in tools and expanded storage space for future customization.

---

## Overview

HarryWrt is not a heavily modified OpenWrt fork.

It keeps the official OpenWrt experience and interface style while improving the default environment for real-world usage:

- Clean base system (close to upstream OpenWrt)
- Useful built-in tools for daily administration
- Expanded root filesystem size for future extension
- Stable defaults with predictable behavior
- Easy to extend with additional packages

---

## Firmware Information

- Base: OpenWrt 24.10.5
- Target: x86_64 (generic)
- Edition: Clean
- Rootfs size: **1024MB (1GB)**
- Image types: BIOS + UEFI supported

---

## Included Packages

### Web UI

- LuCI (HTTPS enabled)
- luci-compat

### Theme

- Argon theme is included
- Argon is **NOT enabled by default**
- Default UI remains the official OpenWrt Bootstrap style

### Tools

- bash
- curl
- wget-ssl
- unzip
- htop
- openssl-util
- ca-bundle

### Network Utilities

- ip-full
- iperf3
- tcpdump
- ethtool
- resolveip

### Firewall / Kernel

- nftables (fw4)
- iptables-nft
- kmod-tun

### Extended System Environment

HarryWrt includes additional common runtime libraries and kernel modules to improve compatibility with third-party applications and offline installations.

- coreutils
- coreutils-base64
- coreutils-nohup
- libev
- libsodium
- libudns
- libuci-lua
- kmod-nft-tproxy
- kmod-nft-socket
- kmod-nft-compat
- kmod-inet-diag
- kmod-netlink-diag

---

## Default Settings

- Hostname: `HarryWrt`
- Timezone: `Asia/Hong_Kong`
- Default LAN IP: `192.168.1.1`
- Default login: `root`
- Default password: *(none)*

---

## Web UI Access

After booting, HarryWrt will use the default LAN address and provide DHCP service for connected clients.

You can access LuCI Web UI at:

https://192.168.1.1

To change LAN IP address:

vi /etc/config/network

> Note: Your browser may show an SSL warning due to the self-signed certificate. This is normal.

---

## Recommended Images

HarryWrt provides both BIOS and UEFI images.

Recommended choices:

- `squashfs-uefi.img.gz` *(most modern systems)*
- `squashfs-bios.img.gz` *(legacy BIOS systems)*

---

## Optional: Enable Argon Theme

Argon theme is included but not enabled by default.

To enable it:

LuCI → System → System → Language and Style → Theme → Argon

---

## Optional: Install Additional LuCI Applications

HarryWrt Clean Edition does not include extra LuCI applications by default.

Users may install additional LuCI packages manually by uploading `.ipk` files through the Web UI or installing via SSH.

Example upstream projects:

https://github.com/Openwrt-Passwall/openwrt-passwall2

---

## Integrity Verification

Each release includes a `SHA256SUMS` file.

You can verify the downloaded images:

sha256sum -c SHA256SUMS

---

## Disclaimer

HarryWrt is provided as-is without warranty.

This firmware is based on official OpenWrt sources and does not include hidden services, telemetry, or proprietary components.

---

## License

HarryWrt follows the licensing model of OpenWrt.

OpenWrt is licensed under **GPL-2.0**.

This repository includes build scripts and configurations that follow the same open-source principles.

---

## Credits

- OpenWrt Project
- LuCI Project
- Argon Theme by jerrykuku
- GitHub Actions build system

---

## Author

HarryWrt Project  
Maintained by: **harryheros**
