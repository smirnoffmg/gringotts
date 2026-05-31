---
id: TASK-0016
status: todo
feature_id: FEAT-0001
title: Write USB installer creation script and instructions
---

# Write USB Installer Creation Script and Instructions

## Goal

Provide a script and instructions for combining the official Debian 13 netinstall ISO with `preseed.cfg` into a bootable USB drive. The output is a single USB the user can boot on the Beelink ME Mini to produce the partition layout from ADR-0002.

## Scope

- Write `installer/build-usb.sh`:
  - Accepts two arguments: path to the Debian 13 netinstall ISO and target USB device (e.g. `/dev/sdb`).
  - Verifies the ISO SHA-256 against the official Debian checksum before proceeding.
  - Writes the ISO to the USB with `dd` (or `cp` for UEFI-compatible ISOs).
  - Injects `preseed.cfg` into the USB at the path the Debian installer expects (`/` of the ISO filesystem, or via a GRUB parameter pointing at a second partition).
  - Prints clear confirmation of what device will be written and requires `yes` before proceeding — the USB write is destructive.
- Write `installer/README.md` covering two paths — VM testing and real hardware:
  - **Testing in UTM (do this first):** link to TASK-0015 VM setup instructions; confirm the preseed works before touching the Beelink.
  - **Real hardware:** where to download the Debian 13 netinstall ISO and its official checksum; how to run `build-usb.sh`; how to configure the Beelink BIOS (boot order, Secure Boot off); what the installer does and does not automate (password is still prompted); how to verify the install succeeded (`blkid -L gringotts`, `ssh goblin@<ip>`).

## Acceptance Criteria

- `installer/build-usb.sh` runs on macOS and Linux.
- Script verifies ISO checksum before writing; exits with a clear error if checksum fails.
- Script requires explicit confirmation before writing to the USB device.
- The README VM path (UTM) is verified before the real-hardware path is documented — no instructions are written for hardware steps that haven't been tested in a VM first.
- A user following `installer/README.md` with no prior Linux experience can produce a working bootable USB and complete the Debian install on the Beelink.

## Dependencies

- TASK-0015 (`preseed.cfg` must exist before the build script can inject it)
