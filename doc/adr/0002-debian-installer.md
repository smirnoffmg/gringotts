---
id: ADR-0002
title: Debian 13 USB Installer for Beelink ME Mini
status: proposed
relates_to: [FEAT-0001]
---

# ADR-0002 — Debian 13 USB Installer for Beelink ME Mini

## Status

Proposed

## Context

The provisioning wizard (ADR-0001) assumes Debian 13 is already running on the target device. Getting Debian onto the Beelink ME Mini requires a bootable USB installer. The partition layout is a prerequisite architectural decision: it determines where the ZFS `tank` pool lives, and the wizard depends on finding the data partition in a known location rather than asking the user to identify it at runtime.

Two decisions have meaningful consequences:

1. How the installer is built and distributed.
2. What partition layout it produces.

## Decision

### 1. Debian preseed over netinstall ISO

The installer is a standard Debian 13 netinstall ISO combined with a `preseed.cfg` file that automates partitioning and base system configuration. The user writes the ISO to a USB drive, places `preseed.cfg` at the expected path, boots from USB, and the installer runs unattended past the partitioning and package selection steps.

No custom ISO is built. The netinstall ISO is the official Debian release; only the preseed file is gringotts-maintained.

**Rejected alternative:** Custom ISO — reproducible and self-contained, but requires ISO build tooling and re-building on every Debian point release. The preseed approach reuses the official ISO and only the preseed needs to be kept current.

**Rejected alternative:** Live USB + install script — most flexible, but debootstrap-based installs are fragile and harder to test than a preseed.

### 2. Partition layout

The NVMe is partitioned as follows:

```
NVMe (e.g. /dev/nvme0n1):
├── p1   512 MB    EFI System Partition (vfat)
├── p2     1 GB    /boot (ext4)
├── p3    32 GB    /     (ext4) Debian OS root
└── p4  remainder  gringotts-data (unformatted, GPT label: gringotts)
```

`p4` is created by the preseed as a plain Linux partition covering all remaining NVMe space. It is left unformatted. The wizard finds it via GPT partition label (`blkid -L gringotts`) and creates the ZFS `tank` pool on it — no user prompt needed for device selection.

**Rejected alternative:** Leaving the remaining space truly unallocated — the wizard would need to calculate free sectors and create the partition itself, adding parted/gdisk as a wizard dependency and a destructive partitioning step inside the wizard.

## Consequences

- The preseed file is a maintained artifact. It must be updated when Debian point releases change installer behaviour or when the target partition sizes change.
- The 30 GB OS root is fixed at install time. Resizing it later requires booting from external media.
- The wizard's ZFS pool creation step is simplified: it looks up the `gringotts` GPT label rather than presenting a device picker to the user.
- The preseed requires a network connection during install (netinstall fetches packages). The Beelink must be connected via ethernet during the installer run.
