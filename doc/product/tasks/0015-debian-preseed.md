---
id: TASK-0015
status: todo
feature_id: FEAT-0001
title: Write Debian 13 preseed.cfg for Beelink ME Mini
---

# Write Debian 13 preseed.cfg for Beelink ME Mini

## Goal

Write the `preseed.cfg` that automates a Debian 13 netinstall on the Beelink ME Mini, producing the partition layout defined in ADR-0002. The file lives at `installer/preseed.cfg` in the repo.

## Scope

The preseed must automate:

- **Locale and keyboard**: `en_US.UTF-8`, UTC timezone.
- **Network**: DHCP on the first ethernet interface; hostname `gringotts`.
- **Partitioning** (via `partman-auto`):
  - Disk: the single NVMe (`/dev/nvme0n1`). Preseed must not wipe the wrong disk if multiple block devices are present.
  - Recipe:
    - `p1`: 512 MB, EFI System Partition, vfat
    - `p2`: 1024 MB, `/boot`, ext4
    - `p3`: 30720 MB, `/`, ext4
    - `p4`: remainder, type `Linux filesystem`, GPT label `gringotts`, no filesystem (left unformatted)
- **Base packages**: `openssh-server`, `sudo`, `curl`. No desktop environment.
- **User**: create a non-root user `goblin` in the `sudo` group; password set interactively (not hardcoded in preseed).
- **SSH**: enable and start `openssh-server` on first boot.
- **Bootloader**: GRUB on EFI.
- **Post-install**: no custom scripts in this task — the wizard handles the rest.

## Acceptance Criteria

- `installer/preseed.cfg` exists in the repo.
- Tested in UTM (see VM setup below): installer completes unattended, produces the correct partition layout, and boots into a working Debian 13 system.
- `blkid -L gringotts` on the installed system returns the path to `p4`.
- SSH is accessible on first boot with the `goblin` user.
- No secrets (passwords, keys) hardcoded in the preseed file.

## Dependencies

- ADR-0002 (partition layout spec)

## Notes

### VM setup for local testing (UTM on macOS)

UTM is the recommended test environment on macOS. VirtualBox has had driver issues on macOS Sequoia; UTM uses QEMU and works reliably.

1. Install UTM from [utm.app](https://utm.app) (free).
2. Create a new VM:
   - **Architecture**: x86\_64
   - **System**: Standard PC (Q35 + ICH9)
   - **Boot**: UEFI (enable in UTM's "BIOS" dropdown — must not be legacy BIOS)
   - **CPU**: 2+ cores; **RAM**: 2 GB minimum
   - **Drive 1**: NVMe, 64 GB (thin-provisioned) — simulates the Beelink NVMe
   - **Drive 2**: attach the Debian 13 netinstall ISO as a CD-ROM
3. Add a network interface in NAT mode (for the netinstall to fetch packages).
4. Boot the VM, interrupt the GRUB menu, and append `auto=true priority=critical url=<preseed-url>` to the boot parameters (or use the `build-usb.sh` injection method if testing from a virtual USB image).
5. After install completes and the VM reboots, verify:
   - `lsblk` shows the four expected partitions on `/dev/vda` (UTM uses VirtIO block; the preseed targets `/dev/nvme0n1` — see note below)
   - `blkid -L gringotts` returns `/dev/vda4`
   - `ssh goblin@<vm-ip>` connects successfully

**NVMe naming in UTM:** UTM's NVMe drive appears as `/dev/nvme0n1` when the drive interface is set to NVMe in UTM settings — confirm this is selected, not VirtIO. This matches the preseed's target device and the real Beelink hardware.
