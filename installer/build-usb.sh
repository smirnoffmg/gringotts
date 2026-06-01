#!/usr/bin/env bash
# build-usb.sh — download the Debian 13 netinstall ISO, embed preseed.cfg,
#                and optionally write it to a USB drive
#
# Usage:
#   ./build-usb.sh                        # download ISO, create modified ISO only
#   ./build-usb.sh [iso] [device]
#
#   iso     path to an existing Debian 13 netinstall ISO (skips download if present)
#   device  USB block device to write to (e.g. /dev/disk4 on macOS, /dev/sdb on Linux)
#
# Examples:
#   ./build-usb.sh                                                    # download + build
#   ./build-usb.sh ~/Downloads/debian-13-amd64-netinst.iso           # use existing ISO
#   ./build-usb.sh ~/Downloads/debian-13-amd64-netinst.iso /dev/disk4
#
# Requires: curl, xorriso
#   macOS:  brew install xorriso          (curl is pre-installed)
#   Linux:  sudo apt install curl xorriso

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRESEED="$SCRIPT_DIR/preseed.cfg"
DEBIAN_CDN="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd"
# ISO cache — override with GRINGOTTS_ISO_CACHE env var if needed
ISO_CACHE_DIR="${GRINGOTTS_ISO_CACHE:-${HOME}/.cache/gringotts/iso}"

ISO="${1:-}"
DEVICE="${2:-}"

# ── helpers ────────────────────────────────────────────────────────────────────

die()  { echo "Error: $*" >&2; exit 1; }
info() { echo "==> $*"; }

portable_sed_inplace() {
  local expr="$1" file="$2"
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "$expr" "$file"
  else
    sed -i "$expr" "$file"
  fi
}

checksum() {
  if command -v sha256sum &>/dev/null; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# ── checks ─────────────────────────────────────────────────────────────────────

[[ ! -f "$PRESEED" ]] && die "preseed.cfg not found at: $PRESEED"
command -v curl    &>/dev/null || die "curl is not installed."
command -v xorriso &>/dev/null || die "xorriso is not installed.
  macOS:  brew install xorriso
  Linux:  sudo apt install xorriso"

if [[ -n "$DEVICE" ]] && [[ ! -b "$DEVICE" ]]; then
  die "device not found or not a block device: $DEVICE"
fi

# ── download ISO if needed ─────────────────────────────────────────────────────

# Fetch SHA256SUMS from Debian CDN to get the current ISO filename and checksum.
# This also avoids hardcoding a checksum that goes stale on every point release.
info "Fetching Debian ISO metadata..."
SHA256SUMS=$(curl -fsSL "$DEBIAN_CDN/SHA256SUMS") \
  || die "Could not fetch SHA256SUMS from $DEBIAN_CDN"

ISO_FILENAME=$(echo "$SHA256SUMS" | awk '/netinst\.iso$/{print $2}' | head -1)
[[ -n "$ISO_FILENAME" ]] || die "Could not find netinstall ISO in SHA256SUMS"
EXPECTED_SHA256=$(echo "$SHA256SUMS" | awk "/netinst\.iso$/{print \$1}" | head -1)

# Resolve ISO path — always cache at the fixed location
CACHED_ISO="$ISO_CACHE_DIR/$ISO_FILENAME"
if [[ -z "$ISO" ]]; then
  ISO="$CACHED_ISO"
fi

if [[ -f "$CACHED_ISO" ]]; then
  info "Using cached ISO: $CACHED_ISO"
  ISO="$CACHED_ISO"
else
  info "Downloading $ISO_FILENAME to $ISO_CACHE_DIR..."
  mkdir -p "$ISO_CACHE_DIR"
  curl -fL --progress-bar "$DEBIAN_CDN/$ISO_FILENAME" -o "$CACHED_ISO" \
    || die "Download failed."
  info "Download complete."
  ISO="$CACHED_ISO"
fi

# ── verify ISO checksum ────────────────────────────────────────────────────────

info "Verifying ISO checksum..."
ACTUAL=$(checksum "$ISO")
[[ "$ACTUAL" == "$EXPECTED_SHA256" ]] || die "checksum mismatch.
  Expected: $EXPECTED_SHA256
  Actual:   $ACTUAL"
info "Checksum OK."

# ── build modified ISO ─────────────────────────────────────────────────────────

TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

OUTPUT_ISO="$(dirname "$ISO")/$(basename "${ISO%.iso}")-gringotts.iso"

info "Extracting boot configs and initrd from ISO..."

# ── GRUB config (UEFI boot — required for Beelink) ───────────────────────────
GRUB_CFG="$TMPDIR_WORK/grub.cfg"
xorriso -indev "$ISO" -osirrox on \
  -extract /boot/grub/grub.cfg "$GRUB_CFG" -- 2>/dev/null \
  || die "Could not extract /boot/grub/grub.cfg — is this a Debian 13 netinstall ISO?"
chmod u+w "$GRUB_CFG"

# ── isolinux txt.cfg (legacy BIOS — optional) ────────────────────────────────
ISOLINUX_CFG="$TMPDIR_WORK/txt.cfg"
HAS_ISOLINUX=false
xorriso -indev "$ISO" -osirrox on \
  -extract /isolinux/txt.cfg "$ISOLINUX_CFG" -- 2>/dev/null \
  && { HAS_ISOLINUX=true; chmod u+w "$ISOLINUX_CFG"; } || true

# ── initrd — preseed will be prepended to both regular and GTK variants ───────
INITRD_ORIG="$TMPDIR_WORK/initrd.gz"
xorriso -indev "$ISO" -osirrox on \
  -extract /install.amd/initrd.gz "$INITRD_ORIG" -- 2>/dev/null \
  || die "Could not extract /install.amd/initrd.gz from ISO."

# GTK initrd is used by the "Graphical install" entry (GRUB default entry 0).
# Without patching it too, preseed never loads when GRUB times out on that entry.
GTK_INITRD_ORIG="$TMPDIR_WORK/gtk-initrd.gz"
HAS_GTK_INITRD=false
xorriso -indev "$ISO" -osirrox on \
  -extract /install.amd/gtk/initrd.gz "$GTK_INITRD_ORIG" -- 2>/dev/null \
  && HAS_GTK_INITRD=true || true

info "Embedding preseed.cfg into initrd..."

# Prepend an UNCOMPRESSED cpio archive containing preseed.cfg to each initrd.
# Uncompressed cpio first, followed by the original (gzip/xz) initrd, is the
# form the kernel expects for prepended initrd overlays.
PRESEED_CPIO="$TMPDIR_WORK/preseed-prepend.cpio"
(cd "$TMPDIR_WORK" && \
  cp "$PRESEED" preseed.cfg && \
  echo preseed.cfg | cpio -o -H newc 2>/dev/null > "$PRESEED_CPIO")

INITRD_NEW="$TMPDIR_WORK/initrd-preseed.gz"
cat "$PRESEED_CPIO" "$INITRD_ORIG" > "$INITRD_NEW"

GTK_INITRD_NEW=""
if $HAS_GTK_INITRD; then
  GTK_INITRD_NEW="$TMPDIR_WORK/gtk-initrd-preseed.gz"
  cat "$PRESEED_CPIO" "$GTK_INITRD_ORIG" > "$GTK_INITRD_NEW"
fi

info "Patching boot configs for auto mode..."

# Set GRUB default to entry 1 ("Install", non-graphical) and add a 5-second
# countdown. The graphical entry (index 0) and the Install entry (index 1)
# both point to different initrds; defaulting to index 1 avoids ambiguity.
printf 'set default=1\nset timeout=5\n' | cat - "$GRUB_CFG" > "$GRUB_CFG.tmp" \
  && mv "$GRUB_CFG.tmp" "$GRUB_CFG"

# Append auto=true priority=critical file=/preseed.cfg to every linux kernel
# line. file=/preseed.cfg explicitly tells the installer to load the preseed
# we embedded in the initrd — without it the file is present but ignored.
AUTO_PARAMS="auto=true priority=critical file=/preseed.cfg DEBCONF_DEBUG=5"
portable_sed_inplace \
  "/^[[:space:]]*linux[^[:space:]]*[[:space:]]/s|$| $AUTO_PARAMS|" \
  "$GRUB_CFG"

if $HAS_ISOLINUX; then
  portable_sed_inplace \
    "s|append |append $AUTO_PARAMS |g" \
    "$ISOLINUX_CFG"
fi

info "Patched kernel line(s) in grub.cfg:"
grep -E '^[[:space:]]*linux[^[:space:]]*[[:space:]]' "$GRUB_CFG" | head -4 \
  || echo "  WARNING: no linux lines matched — check ISO format"

info "Building modified ISO: $(basename "$OUTPUT_ISO")..."

MAP_ARGS=(
  -map "$INITRD_NEW" /install.amd/initrd.gz
  -map "$GRUB_CFG"   /boot/grub/grub.cfg
)
[[ -n "$GTK_INITRD_NEW" ]] && MAP_ARGS+=( -map "$GTK_INITRD_NEW" /install.amd/gtk/initrd.gz )
$HAS_ISOLINUX && MAP_ARGS+=( -map "$ISOLINUX_CFG" /isolinux/txt.cfg )

# xorriso exits with 32 when it emits only WARNING messages (e.g. volume label
# compliance warnings) — the ISO is written correctly. Suppress that so set -e
# doesn't abort; verify success by checking the output file instead.
rm -f "$OUTPUT_ISO"
xorriso -indev "$ISO" \
  -outdev "$OUTPUT_ISO" \
  "${MAP_ARGS[@]}" \
  -boot_image any replay \
  2>/dev/null || true

[[ -f "$OUTPUT_ISO" ]] || die "ISO creation failed — xorriso did not produce output."
info "Modified ISO created: $OUTPUT_ISO"

# ── write to USB (optional) ────────────────────────────────────────────────────

if [[ -z "$DEVICE" ]]; then
  echo ""
  echo "No USB device specified. To write to USB:"
  echo "  $0 $ISO <device>"
  echo ""
  echo "To test in UTM: attach $OUTPUT_ISO as the CD-ROM drive."
  exit 0
fi

echo ""
echo "About to write:"
echo "  Image:  $OUTPUT_ISO"
echo "  Device: $DEVICE"
echo ""
echo "WARNING: this will erase all data on $DEVICE."
read -r -p "Type \"yes\" to continue: " confirm
[[ "$confirm" == "yes" ]] || { echo "Aborted."; exit 0; }

info "Writing to $DEVICE (this may take a few minutes)..."
if [[ "$(uname)" == "Darwin" ]]; then
  diskutil unmountDisk "$DEVICE" 2>/dev/null || true
  RAW_DEVICE="${DEVICE/disk/rdisk}"
  sudo dd if="$OUTPUT_ISO" of="$RAW_DEVICE" bs=4m
  diskutil eject "$DEVICE" 2>/dev/null || true
else
  umount "${DEVICE}"* 2>/dev/null || true
  sudo dd if="$OUTPUT_ISO" of="$DEVICE" bs=4M status=progress
  sync
fi

info "Done. USB is ready — boot the Beelink from it."
echo "The installer will run automatically and stop once to ask for the goblin user password."
