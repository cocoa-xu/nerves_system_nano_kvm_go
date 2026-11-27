# Boot loaders

The boot ROM loads `boot.bin` from the first FAT32 partition of the SD card,
and `boot.bin` (SPL) loads `uboot.bin` from the same partition. Both carry
the 1 KiB Axera image header and a payload for the GZIPD block. SPL runs
U-Boot in AArch32; U-Boot's `go64` warm-resets the cores into AArch64 and
enters `bl31.bin`, which the slot's FIT image carries with Linux, and BL31
starts Linux.

- `boot.bin`: the stock SPL of the NanoKVM-Go firmware v1.0.10, unchanged.
  Sipeed publishes its source, `boot/bl1` of
  [`maix_ax620e_sdk`](https://github.com/sipeed/maix_ax620e_sdk), under the
  MIT license.
- `uboot.bin`: U-Boot 2020.04 from
  [`cocoa-xu/u-boot-ax620e`](https://github.com/cocoa-xu/u-boot-ax620e),
  branch `ax620e-2020.04` (be209481), `configs/nanokvm_go_defconfig`: the
  U-Boot of Sipeed's SDK, with its history and our changes, packed with the
  SDK's `ax_gzip` and image signing script. It runs the Nerves A/B boot in
  `uboot/uboot.env`. Like U-Boot, it is under GPL-2.0, and that branch is its
  source.

- `bl31.bin`: BL31 of TF-A 2.7 for the AX620E, from `boot/atf` of the same
  SDK as Sipeed publishes it: Arm's TF-A (BSD-3-Clause) with Axera's AX620E
  platform (MIT, as the SDK). It provides PSCI, through which Linux starts
  the second core, and keeps its 256 KiB at 0x40040000.

`boot.bin` and `uboot.bin` are kept as binaries until the GZIPD packer has an
open implementation that Buildroot can run; `bl31.bin` until the system
builds TF-A itself.

## Rebuilding `uboot.bin`

On x86-64 Linux, with Arm GNU Toolchain 10.3-2021.07
(`arm-none-linux-gnueabihf`) on the `PATH` and Python 3 with the `rsa`
package:

```sh
curl -L https://github.com/cocoa-xu/u-boot-ax620e/archive/be209481ec9810612fbcbb88909ed695321a3fb9.tar.gz | tar -xz
uboot=$PWD/u-boot-ax620e-be209481ec9810612fbcbb88909ed695321a3fb9
git clone --filter=blob:none --no-checkout https://github.com/sipeed/maix_ax620e_sdk
git -C maix_ax620e_sdk sparse-checkout set build tools
git -C maix_ax620e_sdk checkout d781b0bc65f268080a18cdb957aa8df8ca5ae86d
sdk=$PWD/maix_ax620e_sdk
out=$PWD/uboot
make="make -C $uboot O=$out/build CROSS_COMPILE=arm-none-linux-gnueabihf- \
  HOME_PATH=$sdk PROJECT=AX620Q_emmc_arm32_k419_sipeed_nanoagent KCFLAGS=-DUBOOT_IMG_HEADER_BASE=0x44000000"
$make nanokvm_go_defconfig
$make -j"$(nproc)"
cd "$out"
cp build/u-boot.bin .
"$sdk/tools/ax_gzip_tool/ax_gzip" -9 u-boot.bin
python3 "$sdk/build/tools/imgsign/sec_boot_AX620E_sign.py" -i u-boot_axgzip.bin -o uboot.bin \
  -pub "$sdk/tools/imgsign/public.pem" -prv "$sdk/tools/imgsign/private.pem" -cap 0x54FAFE -key_bit 2048
```

With `SOURCE_DATE_EPOCH=1795701850` in the environment, which sets the
build date U-Boot prints, this gives the `uboot.bin` here byte for byte
(MD5 `b8cdedd8e1a597fb3767fa22fd93ce46`), whatever the directory. U-Boot
is built from the tarball: in a git clone it adds the commit to its version,
and the image differs.

Sipeed's SDK, unchanged, gives the project's settings and the tools, all in
`build` and `tools`. `ax_gzip` is its packer for the GZIPD block, an x86-64
program without source. The image is signed with the SDK's own key, the one
the stock SPL takes (see [`docs/hardware.md`](../docs/hardware.md)).

## Rebuilding `bl31.bin`

On x86-64 Linux, with Arm GNU Toolchain 10.3-2021.07
(`aarch64-none-linux-gnu`) on the `PATH`:

```sh
git clone --filter=blob:none --no-checkout https://github.com/sipeed/maix_ax620e_sdk
git -C maix_ax620e_sdk sparse-checkout set boot/atf
git -C maix_ax620e_sdk checkout d781b0bc65f268080a18cdb957aa8df8ca5ae86d
make -C maix_ax620e_sdk/boot/atf/arm-trusted-firmware-2.7 \
  CROSS_COMPILE=aarch64-none-linux-gnu- PLAT=ax620e DEBUG=0 \
  BUILD_STRING=v2.7 BUILD_MESSAGE_TIMESTAMP='"2026-11-27"' \
  EXT_CFLAGS="-DATF_IMG_ADDR=0x40040000 -DATF_IMG_PKG_SIZE=0x40000" bl31
```

This gives `build/ax620e/release/bl31.bin`, the `bl31.bin` here byte for
byte (MD5 `ed75e2c76aa424f27a46f13fa560595a`), whatever the directory.
