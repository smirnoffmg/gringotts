# Gringotts Installer

Automated Debian 13 installer for the Beelink ME Mini. Produces the partition layout required by the provisioning wizard.

**Always test in UTM first. Do not run on the Beelink until the UTM test passes.**

---

## What it does

Builds a modified Debian 13 netinstall ISO with `preseed.cfg` embedded. The installer runs fully automatically — the only interactive step is setting the `goblin` user password.

Partition layout produced:

```
p1   512 MB   EFI
p2     1 GB   /boot (ext4)
p3    30 GB   /     (ext4)
p4  remainder data  (ext4, labelled "gringotts" — wizard creates ZFS tank here)
```

---

## Prerequisites

**Install xorriso** (required to build the modified ISO):
```bash
brew install xorriso          # macOS
sudo apt install xorriso      # Linux
```

---

## Path 1 — Test in UTM (do this first)

### 1. Build the modified ISO

```bash
chmod +x installer/build-usb.sh
./installer/build-usb.sh
```

This downloads the current Debian 13 netinstall ISO to `~/.cache/gringotts/iso/`, verifies its checksum against the official Debian SHA256SUMS, embeds `preseed.cfg`, and creates `~/.cache/gringotts/iso/debian-XX-amd64-netinst-gringotts.iso`.

The ISO is cached — subsequent runs reuse it without re-downloading. Override the cache location with `GRINGOTTS_ISO_CACHE=/your/path ./build-usb.sh`.

### 2. Create the UTM VM

1. Open UTM → **+** → **Emulate**
2. **Operating System**: Other
3. **Architecture**: x86\_64
4. **System**: Standard PC (Q35 + ICH9)
5. **RAM**: 2048 MB; **CPU cores**: 2
6. After creation, open VM settings:
   - **System** → confirm **UEFI** is selected (not legacy BIOS)
   - **Drives** → select the existing drive → set interface to **NVMe**
   - **Drives** → **New Drive** → **Import** → select `~/.cache/gringotts/iso/debian-XX-amd64-netinst-gringotts.iso` → interface **USB**
7. **Network**: Shared Network (NAT)

### 3. Install

Boot the VM. The installer runs automatically. It will stop once to ask for the `goblin` user password — set it and confirm.

When the install finishes the VM powers off. **Before starting it again, remove the ISO drive**: VM settings → Drives → select the ISO entry → Remove. If you skip this, UTM boots from the ISO again and the install loops.

### 4. Verify

Find the VM's IP in UTM or from the console (`ip addr`), then:

```bash
ssh goblin@<vm-ip>
```

Inside the VM:

```bash
lsblk                    # 4 partitions on nvme0n1
blkid -L gringotts       # /dev/nvme0n1p4
sudo -l                  # full sudo access
```

Expected `lsblk`:
```
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
nvme0n1     259:0    0   64G  0 disk
├─nvme0n1p1 259:1    0  512M  0 part /boot/efi
├─nvme0n1p2 259:2    0    1G  0 part /boot
├─nvme0n1p3 259:3    0   30G  0 part /
└─nvme0n1p4 259:4    0 32.5G  0 part
```

**Keep this VM — it becomes the test environment for the provisioning wizard.**

---

## Path 2 — Real hardware (Beelink ME Mini)

Complete Path 1 successfully before following these steps.

### 1. Write to USB

```bash
./installer/build-usb.sh /dev/diskN
```

The cached ISO from the UTM test is reused automatically — no re-download needed.

Replace `/dev/diskN` with your USB drive (`diskutil list` to find it on macOS).

### 2. Configure Beelink BIOS

1. Power on the Beelink, press **`Delete`** or **`F7`** to enter BIOS
2. **Secure Boot**: Disabled
3. **Boot order**: USB first
4. Save and exit

### 3. Install

Boot from USB. The installer runs automatically and stops once for the `goblin` password. After reboot, verify with `blkid -L gringotts` and `ssh goblin@<ip>`.
