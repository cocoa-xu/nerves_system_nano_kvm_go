#!/bin/sh

set -e

FWUP_CONFIG=$NERVES_DEFCONFIG_DIR/fwup.conf

# The kernel slots hold a FIT image of the zImage and the device tree
cp $NERVES_DEFCONFIG_DIR/kernel.its $BINARIES_DIR
(cd $BINARIES_DIR && $HOST_DIR/bin/mkimage -f kernel.its kernel.itb > /dev/null)

# Run the common post-image processing for nerves
$BR2_EXTERNAL_NERVES_PATH/board/nerves-common/post-createfs.sh $TARGET_DIR $FWUP_CONFIG
