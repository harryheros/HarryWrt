# HarryWrt

HarryWrt is a clean and performance-focused OpenWrt build for x86_64 systems.

This project is based on the official OpenWrt source code and is designed to provide a minimal, stable, and customizable firmware image with a clean LuCI experience.

---

## Base Information

- Base: OpenWrt 24.10.5
- Target: x86_64 (generic)
- Profile: Clean Edition
- Default Web UI: LuCI (HTTPS)
- Default Theme: Argon
- Default Hostname: HarryWrt
- Default Timezone: Asia/Hong_Kong
- Rootfs Size: 1024MB (1GB)

---

## Download

Firmware images are available in the Releases section.

This repository provides multiple variants for different boot modes and filesystem types.

---

## Firmware Variants

This project generates 4 main firmware images:

- squashfs BIOS
- squashfs UEFI
- ext4 BIOS
- ext4 UEFI

---

## Recommended Choice

For most users, the recommended firmware is:

- squashfs UEFI image

If your system does not support UEFI or uses legacy boot mode, use:

- squashfs BIOS image

---

## File Naming

Released firmware images follow this naming format:

HarryWrt-24.10.5-clean-vX.X-x86_64-squashfs-uefi.img.gz
HarryWrt-24.10.5-clean-vX.X-x86_64-squashfs-bios.img.gz
HarryWrt-24.10.5-clean-vX.X-x86_64-ext4-uefi.img.gz
HarryWrt-24.10.5-clean-vX.X-x86_64-ext4-bios.img.gz

---

## BIOS vs UEFI

BIOS images are for legacy boot mode.
UEFI images are for modern systems using UEFI boot mode.

If you are using Proxmox VE, you can select BIOS or UEFI in the VM settings.

---

## squashfs vs ext4

squashfs images are recommended for most users because they provide better stability.

- squashfs is read-only with overlay storage
- safer for upgrades and long-term use
- harder to corrupt by mistake

ext4 images are designed for advanced users.

- ext4 root filesystem is fully writable
- easier to modify system files directly
- higher risk of accidental corruption

---

## Integrity Verification

Each release includes a SHA256SUMS file.

You can verify the downloaded firmware image using:

sha256sum -c SHA256SUMS

---

## Build System

Firmware images are built automatically using GitHub Actions.

The workflow compiles OpenWrt from the official OpenWrt repository and applies a minimal customization layer via the diy.sh script.

---

## Included Packages

This build includes a minimal but practical set of packages:

- LuCI Web UI (HTTPS)
- luci-theme-argon
- luci-compat
- bash
- curl
- htop
- ip-full
- iperf3
- tcpdump
- ethtool
- nftables
- iptables-nft
- kmod-tun
- ca-bundle
- openssl-util

---

## Default Login

The default OpenWrt image does not set a root password.

On first boot, set a password immediately via the LuCI Web UI or SSH.

---

## Web UI Access

After booting, the LAN interface uses the default IP address:

https://192.168.1.1

If your network already uses 192.168.1.0/24 or has an existing DHCP server, the address may be different.
Check your router/DHCP client list to find the assigned IP.

---

## License

This project is based on OpenWrt.

OpenWrt is licensed under GPL-2.0.

All modifications and build scripts in this repository follow the same open-source principles.
