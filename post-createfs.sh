#!/bin/sh

set -e

FWUP_CONFIG=$NERVES_DEFCONFIG_DIR/fwup.conf

# Boot partition image, made like the stock card's (mkfs.fat with the
# partition start in the hidden-sectors field, which fwup's fat_mkfs leaves at
# 0): the boot ROM's FAT32 reader is unknown. Offset and size are
# BOOT_PART_OFFSET/COUNT in fwup_include/fwup-common.conf.
BOOT_VFAT=$BINARIES_DIR/boot.vfat
rm -f $BOOT_VFAT
dd if=/dev/zero of=$BOOT_VFAT bs=512 count=0 seek=262144 2> /dev/null
$HOST_DIR/sbin/mkfs.fat -F 32 -s 1 -h 8192 -n BOOT $BOOT_VFAT > /dev/null
$HOST_DIR/bin/mcopy -i $BOOT_VFAT $BINARIES_DIR/boot.bin $BINARIES_DIR/uboot.bin ::/

# The kernel slots hold a FIT image of the zImage and the device tree
cp $NERVES_DEFCONFIG_DIR/kernel.its $BINARIES_DIR
(cd $BINARIES_DIR && $HOST_DIR/bin/mkimage -f kernel.its kernel.itb > /dev/null)

# Run the common post-image processing for nerves
$BR2_EXTERNAL_NERVES_PATH/board/nerves-common/post-createfs.sh $TARGET_DIR $FWUP_CONFIG
