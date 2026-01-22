#!/usr/bin/env bash
set -euo pipefail

SOURCE_ISO="${1:-}"
OUTPUT_ISO="${2:-}"
VOLUME_LABEL="${VOLUME_LABEL:-CUSTOM_ALMA}"
SOURCE_ISO_URL="${SOURCE_ISO_URL:-https://mirror.2degrees.nz/almalinux/9.7/isos/x86_64/AlmaLinux-9.7-x86_64-minimal.iso}"
ALMA_RELEASE="${ALMA_RELEASE:-9}"
ALMA_BASE_URL="${ALMA_BASE_URL:-https://mirror.2degrees.nz/almalinux}"
HYPERV_PACKAGES_LIST="${HYPERV_PACKAGES:-hyperv-daemons}"
read -r -a HYPERV_PACKAGES <<< "$HYPERV_PACKAGES_LIST"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

if [[ -z "$SOURCE_ISO" ]]; then
  echo "Usage: $0 /path/to/source.iso [/path/to/output-dir-or-file]" >&2
  exit 1
fi

require_cmd curl
require_cmd xorriso
require_cmd dnf
require_cmd createrepo_c

if [[ ! -f "$SOURCE_ISO" ]]; then
  echo "Source ISO not found: $SOURCE_ISO" >&2
  echo "Downloading from ${SOURCE_ISO_URL}..." >&2
  curl -L -o "$SOURCE_ISO" "$SOURCE_ISO_URL"
fi

SOURCE_URL_BASENAME="$(basename "${SOURCE_ISO_URL%%\?*}")"
SOURCE_URL_STEM="${SOURCE_URL_BASENAME%.iso}"
OUTPUT_NAME="kickstart-${SOURCE_URL_STEM}.iso"
if [[ -n "$OUTPUT_ISO" ]]; then
  if [[ "$OUTPUT_ISO" == */ || -d "$OUTPUT_ISO" || "$OUTPUT_ISO" != *.iso ]]; then
    OUTPUT_DIR="${OUTPUT_ISO%/}"
  else
    OUTPUT_DIR="$(dirname "$OUTPUT_ISO")"
  fi
else
  OUTPUT_DIR="$(dirname "$SOURCE_ISO")"
fi
OUTPUT_ISO="${OUTPUT_DIR}/${OUTPUT_NAME}"

WORK_DIR="$(mktemp -d)"
echo "temp folder is: ${WORK_DIR}"
trap 'rm -rf "$WORK_DIR"' EXIT

ISO_DIR="$WORK_DIR/iso"
mkdir -p "$ISO_DIR"
xorriso -osirrox on -indev "$SOURCE_ISO" -extract / "$ISO_DIR"
chmod -R u+w "$ISO_DIR"

pwd
cp "./alma/ks.cfg" "$ISO_DIR/ks.cfg"

cp "./alma/grub.cfg" "$ISO_DIR/EFI/BOOT/grub.cfg"

cp "./alma/isolinux.cfg" "$ISO_DIR/isolinux/isolinux.cfg"

echo "Downloading Hyper-V packages and dependencies..." >&2
PKG_TMP="$WORK_DIR/hyperv-rpms"
mkdir -p "$PKG_TMP"

dnf -y download \
  --resolve \
  --arch x86_64 \
  --releasever "$ALMA_RELEASE" \
  --setopt=install_weak_deps=False \
  --nogpgcheck \
  --destdir "$PKG_TMP" \
  --disablerepo="*" \
  --repofrompath=baseos-local,"${ALMA_BASE_URL}/${ALMA_RELEASE}/BaseOS/x86_64/os" \
  --repofrompath=appstream-local,"${ALMA_BASE_URL}/${ALMA_RELEASE}/AppStream/x86_64/os" \
  --enablerepo=baseos-local \
  --enablerepo=appstream-local \
  "${HYPERV_PACKAGES[@]}"

echo "Adding packages to ISO AppStream repo..." >&2
mkdir -p "$ISO_DIR/AppStream/Packages"
cp -a "$PKG_TMP"/*.rpm "$ISO_DIR/AppStream/Packages/"

APPSTREAM_COMPS="$(ls "$ISO_DIR"/AppStream/repodata/*comps*.xml 2>/dev/null | head -n1 || true)"
if [[ -z "$APPSTREAM_COMPS" ]]; then
  echo "AppStream comps.xml not found; group installs may fail." >&2
  createrepo_c --update "$ISO_DIR/AppStream"
else
  createrepo_c --update -g "$APPSTREAM_COMPS" "$ISO_DIR/AppStream"
fi

xorriso -as mkisofs -o "$OUTPUT_ISO" \
  -b isolinux/isolinux.bin -c isolinux/boot.cat \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot -e images/efiboot.img -no-emul-boot \
  -R -J -v -T -V "${VOLUME_LABEL}" \
  "$ISO_DIR" \
  > ./xorriso.log 2>&1
