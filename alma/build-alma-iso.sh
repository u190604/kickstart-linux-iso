#!/usr/bin/env bash
set -euo pipefail

SOURCE_ISO="${1:-}"
OUTPUT_ISO="${2:-}"
VOLUME_LABEL="${VOLUME_LABEL:-CUSTOM_ALMA}"
SOURCE_ISO_URL="${SOURCE_ISO_URL:-https://mirror.2degrees.nz/almalinux/9.7/isos/x86_64/AlmaLinux-9.7-x86_64-minimal.iso}"

if [[ -z "$SOURCE_ISO" || -z "$OUTPUT_ISO" ]]; then
  echo "Usage: $0 /path/to/source.iso /path/to/output.iso" >&2
  exit 1
fi

if [[ ! -f "$SOURCE_ISO" ]]; then
  echo "Source ISO not found: $SOURCE_ISO" >&2
  echo "Downloading from ${SOURCE_ISO_URL}..." >&2
  curl -L -o "$SOURCE_ISO" "$SOURCE_ISO_URL"
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

ISO_DIR="$WORK_DIR/iso"
mkdir -p "$ISO_DIR"
xorriso -osirrox on -indev "$SOURCE_ISO" -extract / "$ISO_DIR"
chmod -R u+w "$ISO_DIR"

pwd
cp "./alma/ks.cfg" "$ISO_DIR/ks.cfg"

cp "./alma/grub.cfg" "$ISO_DIR/EFI/BOOT/grub.cfg"

cp "./alma/isolinux.cfg" "$ISO_DIR/isolinux/isolinux.cfg"


xorriso -as mkisofs -o "$OUTPUT_ISO" \
  -b isolinux/isolinux.bin -c isolinux/boot.cat \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot -e images/efiboot.img -no-emul-boot \
  -R -J -v -T -V "${VOLUME_LABEL}" \
  "$ISO_DIR" \
  > ./xorriso.log 2>&1
