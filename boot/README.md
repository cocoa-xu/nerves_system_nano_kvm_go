# Boot loaders

The boot ROM loads `boot.bin` from the first FAT32 partition of the SD card,
and `boot.bin` (SPL) loads `uboot.bin` from the same partition. Both carry
the 1 KiB Axera image header and a payload for the GZIPD block.

- `boot.bin`: the stock SPL of the NanoKVM-Go firmware v1.0.10, unchanged.
  Sipeed publishes its source, `boot/bl1` of
  [`maix_ax620e_sdk`](https://github.com/sipeed/maix_ax620e_sdk), under the
  MIT license.
- `uboot.bin`: U-Boot 2020.04 from
  [`cocoa-xu/maix_ax620e_sdk`](https://github.com/cocoa-xu/maix_ax620e_sdk/tree/cocoa/nerves/uboot-ab),
  branch `cocoa/nerves/uboot-ab` (61a4386e), `configs/nanokvm_go_defconfig`, packed with the
  SDK's `ax_gzip` and image signing script. It runs the Nerves A/B boot in
  `uboot/uboot.env`. Like U-Boot, it is under GPL-2.0, and that branch is its
  source.

They are kept as binaries until the GZIPD packer has an open implementation
that Buildroot can run.

## Rebuilding `uboot.bin`

On x86-64 Linux, with Arm GNU Toolchain 10.3-2021.07
(`arm-none-linux-gnueabihf`) on the `PATH` and Python 3 with the `rsa`
package:

```sh
git clone --depth 1 -b cocoa/nerves/uboot-ab https://github.com/cocoa-xu/maix_ax620e_sdk
sdk=$PWD/maix_ax620e_sdk
out=$PWD/uboot
make="make -C $sdk/boot/uboot/u-boot-2020.04 O=$out/build CROSS_COMPILE=arm-none-linux-gnueabihf- \
  HOME_PATH=$sdk PROJECT=AX620Q_emmc_arm32_k419_sipeed_nanoagent KCFLAGS=-DUBOOT_IMG_HEADER_BASE=0x44000000"
$make nanokvm_go_defconfig
$make -j"$(nproc)"
cd "$out"
cp build/u-boot.bin .
"$sdk/tools/ax_gzip_tool/ax_gzip" -9 u-boot.bin
python3 "$sdk/build/tools/imgsign/sec_boot_AX620E_sign.py" -i u-boot_axgzip.bin -o uboot.bin \
  -pub "$sdk/tools/imgsign/public.pem" -prv "$sdk/tools/imgsign/private.pem" -cap 0x54FAFE -key_bit 2048
```

With `SOURCE_DATE_EPOCH=1795141486` in the environment, which sets the
build date U-Boot prints, this gives the `uboot.bin` here byte for byte
(MD5 `71afd23b263d5b0fc38b49495f48c8c2`), whatever the directory. `ax_gzip`
is the SDK's packer for the GZIPD block, an x86-64 program without source.
The image is signed with the SDK's own key, the one the stock SPL takes (see
[`docs/hardware.md`](../docs/hardware.md)).
