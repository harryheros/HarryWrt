# HarryWrt

HarryWrt is a clean and stable OpenWrt build designed for x86_64 systems.

This project focuses on providing a minimal, fast, and reliable OpenWrt base image with LuCI and essential tools pre-installed.

No proxy stack is included by default. Users are free to install and customize additional packages as needed.

---

## Features

- Based on official OpenWrt release
- Clean build (no third-party proxy stack prebuilt)
- LuCI Web UI (HTTPS enabled)
- Argon theme
- luci-compat included
- dnsmasq-full included
- Common diagnostic and system tools included
- Suitable for Proxmox / ESXi / Bare Metal / Cloud VPS

---

## Included Packages

- luci
- luci-ssl
- luci-theme-argon
- luci-compat
- dnsmasq-full
- bash
- curl
- htop
- ca-bundle
- openssl-util
- ip-full
- ipset
- iperf3
- tcpdump
- ethtool
- lsblk
- block-mount
- fdisk
- e2fsprogs
- nftables
- iptables-nft
- kmod-tun
- zoneinfo-asia

---

## Default Settings

- Hostname: HarryWrt
- Timezone: Asia/Hong_Kong
- LuCI Theme: Argon

---

## Firmware Images

Each release provides both BIOS and UEFI images:

- *combined.img.gz (Legacy BIOS)
- *combined-efi.img.gz (UEFI)

---

## Installation

Write image to disk (Linux):

gzip -dc openwrt-*.img.gz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress

Replace /dev/sdX with your target disk.

---

## Proxmox / Virtual Machine

You can import the image into Proxmox as a disk:

qm importdisk <VMID> openwrt-*.img local-lvm

Then attach it as the boot disk.

---

## Web UI Access

After booting, OpenWrt will obtain an IP address via DHCP.

Access LuCI Web UI:

https://OPENWRT_IP/

Replace OPENWRT_IP with the IP address assigned by your DHCP server.

Default login:

- Username: root
- Password: (empty)

You should set a root password immediately.

---

## Upgrading

This build is based on official OpenWrt releases.

To upgrade, download a newer image from Releases and flash it.

---

## Build System

Builds are automated via GitHub Actions.

Source base:

- OpenWrt: v24.10.5

---

## Release Tags

Tag format:

- clean-24.10.5-vX.Y

Example:

- clean-24.10.5-v1.0

---

## License

This repository provides build scripts and configuration only.

OpenWrt is licensed under GPL-2.0.

---

## Disclaimer

This project is provided as-is, without warranty.
Use at your own risk.
