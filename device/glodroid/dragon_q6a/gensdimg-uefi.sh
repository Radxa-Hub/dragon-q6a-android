#!/bin/bash -e
#
# gensdimg-uefi.sh — SD card image generator for Radxa Dragon Q6A (UEFI boot)
#
# Creates a GPT-partitioned SD image with systemd-boot ESP and Android partitions.
# This replaces GloDroid's standard gensdimg.sh which assumes U-Boot.
#
# Usage: ./gensdimg-uefi.sh -C=<PRODUCT_OUT> -E=<ESP_DIR> [-s=<SIZE_GB>] <output.img>
#
# ESP_DIR should contain:
#   EFI/BOOT/BOOTAA64.EFI       — systemd-boot from Radxa OS
#   loader/loader.conf           — systemd-boot config
#   loader/entries/android.conf  — boot entry for Android
#   Android/Image                — kernel binary
#   Android/qcs6490-radxa-dragon-q6a.dtb — DTB
#   Android/ramdisk.img          — combined Android ramdisk

set -euo pipefail

PRODUCT_OUT=""
ESP_DIR=""
SIZE_GB=8
SDIMG=""

for i in "$@"; do
case $i in
    -C=*|--product-out=*)
    PRODUCT_OUT="${i#*=}"
    shift ;;
    -E=*|--esp-dir=*)
    ESP_DIR="${i#*=}"
    shift ;;
    -s=*|--size=*)
    SIZE_GB="${i#*=}"
    shift ;;
    *)
    SDIMG="$i" ;;
esac
done

if [ -z "$PRODUCT_OUT" ] || [ -z "$ESP_DIR" ] || [ -z "$SDIMG" ]; then
    echo "Usage: $0 -C=<PRODUCT_OUT> -E=<ESP_DIR> [-s=<SIZE_GB>] <output.img>"
    exit 1
fi

ALIGN=$((2048 * 512))  # 1 MiB alignment
PTR=$((2048 * 512))    # Start after 1 MiB (GPT header space)
pn=1

add_part() {
    local FILE=$1
    local NAME=$2
    local FILL_REST=${3:-""}
    local SIZE
    SIZE=$(stat "$FILE" -c%s)

    echo "  partition $pn: $NAME ($((SIZE / 1024 / 1024)) MiB) @ offset $PTR"

    if [ -z "$FILL_REST" ]; then
        sgdisk --set-alignment=1 \
            --new "$pn:$((PTR / 512)):$(((PTR + SIZE - 1) / 512))" \
            --change-name="$pn:$NAME" "$SDIMG"
    else
        sgdisk --set-alignment=1 \
            --largest-new="$pn" \
            --change-name="$pn:$NAME" "$SDIMG"
    fi

    dd if="$FILE" of="$SDIMG" bs=4096 count=$((SIZE / 4096 + 1)) \
        seek=$((PTR / 4096)) conv=notrunc 2>/dev/null

    PTR=$(( (PTR + SIZE + ALIGN - 1) / ALIGN * ALIGN ))
    pn=$((pn + 1))
}

echo "==> Creating ${SIZE_GB} GB SD card image: $SDIMG"
dd if=/dev/zero of="$SDIMG" bs=1M count=$((SIZE_GB * 1024)) status=none
sgdisk --zap-all "$SDIMG" >/dev/null

echo "==> Building ESP image (FAT32, 256 MiB)"
ESP_IMG=$(mktemp /tmp/esp-XXXX.img)
dd if=/dev/zero of="$ESP_IMG" bs=1M count=256 status=none
/sbin/mkfs.vfat -F 32 -n "ESP" "$ESP_IMG" >/dev/null

# Copy ESP contents recursively
/usr/bin/mcopy -s -i "$ESP_IMG" "$ESP_DIR"/* ::

echo "==> Creating misc and metadata images"
dd if=/dev/zero of="$PRODUCT_OUT/misc.img" bs=4096 count=$((512 * 1024 / 4096)) status=none
dd if=/dev/zero of="$PRODUCT_OUT/metadata.img" bs=4096 count=$((16 * 1024 * 1024 / 4096)) status=none

# Pre-format metadata as ext4 and bake the AIC8800D80 WiFi firmware into it.
# The AICSemi driver loads firmware via filp_open() at USB probe time (~7.9s),
# which is after switch_root (~7.25s) — ramdisk files are gone by then, and the
# driver does not use request_firmware so firmware_class.path doesn't apply.
# /metadata is the only writable partition mounted that early, hence:
#   cmdline: aic_load_fw_usb.aic_fw_path=/metadata/aic8800_fw/USB/aic8800D80
# NOTE: keep this image SEPARATE from the userdata filler below — a formatted
# ext4 stamped into userdata would be mounted as a 16 MB /data on first boot.
echo "==> Baking AIC8800 WiFi firmware into metadata image"
AIC_FW_DIR="$(dirname "$(readlink -f "$0")")/firmware/aic8800_fw/USB/aic8800D80"
mke2fs -q -t ext4 -b 4096 -I 256 -F "$PRODUCT_OUT/metadata.img"
{
    echo "mkdir /aic8800_fw"
    echo "mkdir /aic8800_fw/USB"
    echo "mkdir /aic8800_fw/USB/aic8800D80"
    for f in "$AIC_FW_DIR"/*; do
        echo "write $f /aic8800_fw/USB/aic8800D80/$(basename "$f")"
    done
} | debugfs -w -f /dev/stdin "$PRODUCT_OUT/metadata.img" >/dev/null 2>&1
debugfs -R "ls /aic8800_fw/USB/aic8800D80" "$PRODUCT_OUT/metadata.img" 2>/dev/null \
    | grep -q fmacfw_8800d80_u02.bin || { echo "ERROR: AIC fw injection into metadata.img failed"; exit 1; }

dd if=/dev/zero of="$PRODUCT_OUT/userdata_blank.img" bs=4096 count=$((16 * 1024 * 1024 / 4096)) status=none

echo "==> Adding partitions to SD image"
add_part "$ESP_IMG" "esp"
add_part "$PRODUCT_OUT/misc.img" "misc"
add_part "$PRODUCT_OUT/boot.img" "boot_a"
add_part "$PRODUCT_OUT/boot.img" "boot_b"
add_part "$PRODUCT_OUT/vendor_boot.img" "vendor_boot_a"
add_part "$PRODUCT_OUT/vendor_boot.img" "vendor_boot_b"
add_part "$PRODUCT_OUT/vbmeta.img" "vbmeta_a"
add_part "$PRODUCT_OUT/vbmeta.img" "vbmeta_b"
add_part "$PRODUCT_OUT/vbmeta_system.img" "vbmeta_system_a"
add_part "$PRODUCT_OUT/vbmeta_system.img" "vbmeta_system_b"
add_part "$PRODUCT_OUT/metadata.img" "metadata"
add_part "$PRODUCT_OUT/super.img" "super"
add_part "$PRODUCT_OUT/userdata_blank.img" "userdata" "fill"

# Set ESP partition type to EFI System Partition
sgdisk --typecode=1:ef00 "$SDIMG"

rm -f "$ESP_IMG"

echo "==> SD image created: $SDIMG ($(du -h "$SDIMG" | cut -f1))"
echo ""
echo "Write to SD card with:"
echo "  dd if=$SDIMG of=/dev/sdX bs=4M status=progress && sync"
echo "  or use Etcher on Windows"
