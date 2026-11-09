#!/usr/bin/env bash
# build-usb.sh — download the Debian 13 netinstall ISO and optionally write it to USB
#
# Usage:
#   ./build-usb.sh                  # download and verify ISO only
#   ./build-usb.sh <device>         # download, verify, and write to USB
#
# Examples:
#   ./build-usb.sh                  # just get the ISO
#   ./build-usb.sh /dev/disk4       # write to USB (macOS)
#   ./build-usb.sh /dev/sdb         # write to USB (Linux)
#
# Requires: curl
# ISO cached at: ~/.cache/gringotts/iso/  (override with GRINGOTTS_ISO_CACHE)

set -euo pipefail

DEBIAN_CDN="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd"
ISO_CACHE_DIR="${GRINGOTTS_ISO_CACHE:-${HOME}/.cache/gringotts/iso}"
DEVICE="${1:-}"

die()  { echo "Error: $*" >&2; exit 1; }
info() { echo "==> $*"; }

checksum() {
  if command -v sha256sum &>/dev/null; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

command -v curl &>/dev/null || die "curl is not installed."

if [[ -n "$DEVICE" ]] && [[ ! -b "$DEVICE" ]]; then
  die "device not found or not a block device: $DEVICE"
fi

info "Fetching Debian ISO metadata..."
SHA256SUMS=$(curl -fsSL "$DEBIAN_CDN/SHA256SUMS") \
  || die "Could not fetch SHA256SUMS from $DEBIAN_CDN"

ISO_FILENAME=$(echo "$SHA256SUMS" | awk '/netinst\.iso$/{print $2}' | head -1)
[[ -n "$ISO_FILENAME" ]] || die "Could not find netinstall ISO in SHA256SUMS"
EXPECTED_SHA256=$(echo "$SHA256SUMS" | awk "/netinst\.iso$/{print \$1}" | head -1)

CACHED_ISO="$ISO_CACHE_DIR/$ISO_FILENAME"

if [[ -f "$CACHED_ISO" ]]; then
  info "Using cached ISO: $CACHED_ISO"
else
  info "Downloading $ISO_FILENAME..."
  mkdir -p "$ISO_CACHE_DIR"
  curl -fL --progress-bar "$DEBIAN_CDN/$ISO_FILENAME" -o "$CACHED_ISO" \
    || die "Download failed."
fi

info "Verifying checksum..."
ACTUAL=$(checksum "$CACHED_ISO")
[[ "$ACTUAL" == "$EXPECTED_SHA256" ]] || die "Checksum mismatch.
  Expected: $EXPECTED_SHA256
  Actual:   $ACTUAL"
info "Checksum OK: $CACHED_ISO"

if [[ -z "$DEVICE" ]]; then
  echo ""
  echo "To write to USB:  $0 <device>"
  echo "Find your device: diskutil list   (macOS)  or  lsblk  (Linux)"
  exit 0
fi

echo ""
echo "About to write:"
echo "  Image:  $CACHED_ISO"
echo "  Device: $DEVICE"
echo ""
echo "WARNING: this will erase all data on $DEVICE."
read -r -p "Type \"yes\" to continue: " confirm
[[ "$confirm" == "yes" ]] || { echo "Aborted."; exit 0; }

info "Writing to $DEVICE (this may take a few minutes)..."
if [[ "$(uname)" == "Darwin" ]]; then
  diskutil unmountDisk "$DEVICE" 2>/dev/null || true
  RAW_DEVICE="${DEVICE/disk/rdisk}"
  sudo dd if="$CACHED_ISO" of="$RAW_DEVICE" bs=4m
  diskutil eject "$DEVICE" 2>/dev/null || true
else
  umount "${DEVICE}"* 2>/dev/null || true
  sudo dd if="$CACHED_ISO" of="$DEVICE" bs=4M status=progress
  sync
fi

info "Done. USB is ready."
