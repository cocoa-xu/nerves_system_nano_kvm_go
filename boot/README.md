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
