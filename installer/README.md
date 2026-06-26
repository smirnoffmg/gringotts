# Gringotts Installer

Stock Debian 13 netinstall on the Beelink ME Mini. Partitioning and post-install setup are manual — the provisioning wizard handles everything after the OS is up.

**Always test in UTM first. Do not run on the Beelink until the UTM test passes.**

---

## Get the ISO

```bash
./installer/build-usb.sh
```

Downloads the current Debian 13 netinstall ISO to `~/.cache/gringotts/iso/`, verifies its checksum against the official Debian SHA256SUMS. Override the cache location with `GRINGOTTS_ISO_CACHE=/your/path`.

---

## Path 1 — Test in UTM (do this first)

### 1. Create the UTM VM

1. Open UTM → **+** → **Emulate**
2. **Operating System**: Other
3. **Architecture**: x86_64
4. **System**: Standard PC (Q35 + ICH9)
5. **RAM**: 2048 MB; **CPU cores**: 2
6. After creation, open VM settings:
   - **System** → confirm **UEFI** is selected (not legacy BIOS)
   - **Drives** → select the existing drive → set interface to **NVMe**
   - **Drives** → **New Drive** → **Import** → select the ISO from `~/.cache/gringotts/iso/` → interface **USB**
7. **Network**: Shared Network (NAT)

### 2. Install

Boot the VM and follow the installer. Partition layout:

```
p1   512 MB    EFI System Partition   /boot/efi
p2   512 MB    ext4                   /boot       noatime
p3    10 GB    ext4                   /           noatime
p4  remainder  —                      —           (leave unformatted — ZFS)
```

When partitioning is done and the install finishes, the VM powers off. **Remove the ISO drive before starting again** (VM settings → Drives → remove ISO entry) — otherwise it boots the installer again.

### 3. Label the ZFS partition

After first boot, SSH in and run:

```bash
sudo parted -s /dev/sda name 4 gringotts
```

The provisioning wizard finds the data partition via `blkid -t PARTLABEL=gringotts`.

### 4. Verify

```bash
ssh goblin@<vm-ip>
lsblk                              # 4 partitions on sda
sudo blkid -t PARTLABEL=gringotts  # /dev/sda4
sudo -l                            # full sudo access
```

---

## Path 2 — Real hardware (Beelink ME Mini)

Complete Path 1 successfully before following these steps.

### 1. Write to USB

```bash
./installer/build-usb.sh /dev/diskN
```

Replace `/dev/diskN` with your USB drive (`diskutil list` to find it on macOS).

### 2. Configure Beelink BIOS

1. Power on, press **`Delete`** or **`F7`** to enter BIOS
2. **Secure Boot**: Disabled
3. **Boot order**: USB first
4. Save and exit

### 3. Install

Same partition layout as UTM, with adjusted sizes:

```
p1   512 MB    EFI System Partition   /boot/efi
p2     1 GB    ext4                   /boot       noatime
p3    40 GB    ext4                   /           noatime
p4  remainder  —                      —           (leave unformatted — ZFS)
```

After reboot, label p4:

```bash
sudo parted -s /dev/nvme0n1 name 4 gringotts
```
