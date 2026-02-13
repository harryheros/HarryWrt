# HarryWrt
[![License: GPL v2](https://img.shields.io/badge/License-GPLv2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![Platform](https://img.shields.io/badge/Platform-BIOS%20%7C%20UEFI-orange.svg)](#)

**HarryWrt** is a clean and stable OpenWrt firmware build, focused on reliability, performance, and long-term usability.

This project is built on official **OpenWrt 24.10.5** sources and is designed for users who want a minimal but powerful base system with extra utilities and expanded storage space for future customization.

---

## Overview

HarryWrt is not a heavily modified OpenWrt fork.

It keeps the official OpenWrt experience and interface style while improving the default environment for real-world usage:

- Clean base system
- Useful built-in tools
- Expanded root filesystem size
- Stable defaults
- Easy to extend

---

## Firmware Information

- Base: OpenWrt 24.10.5
- Target: x86_64 (generic)
- Edition: Clean
- Rootfs size: **1024MB (1GB)**

---

## Included Packages

### Web UI

- LuCI (HTTPS)
- luci-compat

### Theme

- Argon theme is included
- Argon is **NOT enabled by default**
- Default UI remains the official OpenWrt style

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

### Firewall / Kernel

- nftables
- iptables-nft
- kmod-tun

---

## Default Settings

- Hostname: `HarryWrt`
- Timezone: `Asia/Hong_Kong`
- Default IP: `192.168.1.1`
- Default login: `root`
- Default password: (none)

---

## Web UI Access

After booting, OpenWrt will obtain an IP address via DHCP.

You can access LuCI Web UI at:

https://192.168.1.1

---

## Recommended Images

HarryWrt provides both BIOS and UEFI images.

Recommended choices:

- **squashfs-uefi.img.gz** (most modern systems)
- **squashfs-bios.img.gz** (legacy BIOS systems)

---

## Optional: Enable Argon Theme

Argon theme is included but not enabled by default.

To enable it:

LuCI → System → System → Language and Style → Theme → Argon

---

## Optional: Install Passwall2

HarryWrt Clean Edition does not include Passwall2 by default.

Users can install Passwall2 manually from the upstream project releases.

Upstream project:

https://github.com/Openwrt-Passwall/openwrt-passwall2

---

## Integrity Verification

Each release includes a `SHA256SUMS` file.

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
- Passwall2 Project
- GitHub Actions build system

---

## Author

HarryWrt Project  
Maintained by: harryheros
