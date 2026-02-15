# HarryWrt

[![License: GPL v2](https://img.shields.io/badge/License-GPLv2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![Platform](https://img.shields.io/badge/Platform-BIOS%20%7C%20UEFI-orange.svg)](#)

**HarryWrt** is a clean and stable OpenWrt firmware build focused on reliability, performance, and long-term usability.

Built on official **OpenWrt 24.10.5**, HarryWrt is designed for users who want a minimal but powerful base system with useful built-in tools and expanded storage space for future customization.

---

## Overview

HarryWrt is not a heavily modified OpenWrt fork.

It keeps the official OpenWrt experience and interface style while improving the default environment for real-world usage:

- Clean base system with stable defaults
- Useful built-in tools for daily maintenance
- Expanded root filesystem size for future packages
- High compatibility with upstream OpenWrt packages
- Easy to extend without breaking the stock experience

---

## Firmware Information

- Base: OpenWrt 24.10.5
- Target: x86_64 (generic)
- Edition: Clean
- Rootfs size: 1024MB (1GB)

---

## Included Packages

### Web UI

- LuCI (HTTPS)
- luci-compat

### Theme

- Default UI remains the official OpenWrt style (Bootstrap)
- Argon theme is included but NOT enabled by default

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

---

## Default Settings

- Hostname: HarryWrt
- Timezone: Asia/Hong_Kong
- Default LAN IP: 192.168.1.1
- Default login: root
- Default password: (none)

---

## Web UI Access

After booting, HarryWrt will use the default LAN address and provide DHCP service for connected clients.

You can access LuCI Web UI at:

https://192.168.1.1

To change LAN IP address via SSH:

vi /etc/config/network

Note: Your browser may show an SSL warning due to the self-signed certificate. This is normal.

---

## Recommended Images

HarryWrt provides both BIOS and UEFI images.

Recommended choices:

- squashfs-uefi.img.gz (most modern systems)
- squashfs-bios.img.gz (legacy BIOS systems)

---

## Optional: Enable Argon Theme

Argon theme is included but not enabled by default.

To enable it:

LuCI -> System -> System -> Language and Style -> Theme -> Argon

---

## Optional: Customization

HarryWrt is designed to be highly compatible with upstream OpenWrt packages.

Users may install additional LuCI applications (such as monitoring tools, network utilities, proxy clients, or file services) by uploading `.ipk` files through the Web UI or installing via SSH.

---

## Integrity Verification

Each release includes a SHA256SUMS file.

You can verify the downloaded images:

sha256sum -c SHA256SUMS

---

## Disclaimer

HarryWrt is provided as-is without warranty.

This firmware is based on OpenWrt official sources and does not include hidden services, telemetry, or proprietary components.

---

## License

HarryWrt follows the licensing model of OpenWrt.

OpenWrt is licensed under GPL-2.0.

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
Maintained by: harryheros
