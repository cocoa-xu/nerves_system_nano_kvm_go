#!/bin/sh

set -e

# Copy the fwup includes to the images dir
cp -rf $NERVES_DEFCONFIG_DIR/fwup_include $BINARIES_DIR

# Create the fwup ops script to handling MicroSD operations at runtime
# NOTE: revert.fw is the previous, more limited version of this. ops.fw is
#       backwards compatible.
mkdir -p $TARGET_DIR/usr/share/fwup
NERVES_SDK_IMAGES=$BINARIES_DIR $HOST_DIR/usr/bin/fwup -c -f $NERVES_DEFCONFIG_DIR/fwup-ops.conf -o $TARGET_DIR/usr/share/fwup/ops.fw
ln -sf ops.fw $TARGET_DIR/usr/share/fwup/revert.fw

# Boot loaders for the boot partition and TF-A's BL31 (see boot/README.md)
cp $NERVES_DEFCONFIG_DIR/boot/boot.bin $NERVES_DEFCONFIG_DIR/boot/uboot.bin \
	$NERVES_DEFCONFIG_DIR/boot/bl31.bin $BINARIES_DIR

# BlueZ keeps its pairings on the application partition; D-Bus reads the
# machine ID that nanokvm-init writes at boot
rm -rf $TARGET_DIR/var/lib/bluetooth
ln -s /data/bluetooth $TARGET_DIR/var/lib/bluetooth
ln -sf /run/machine-id $TARGET_DIR/etc/machine-id
