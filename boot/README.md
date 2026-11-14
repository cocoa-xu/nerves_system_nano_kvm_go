# Boot loaders

The boot ROM loads `boot.bin` from the first FAT32 partition of the SD card,
and `boot.bin` (SPL) loads `uboot.bin` from the same partition. Both carry
the 1 KiB Axera image header and a payload for the GZIPD block.

- `boot.bin`: the stock SPL of the NanoKVM-Go firmware v1.0.10, unchanged.
- `uboot.bin`: U-Boot 2020.04 from `cocoa-xu/maix_ax620e_sdk`, branch
  `cocoa/nerves/uboot-ab` (d9591096), `configs/nanokvm_go_defconfig`, packed with the
  SDK's `ax_gzip` and image signing script. It runs the Nerves A/B boot in
  `uboot/uboot.env`.

They are kept as binaries until the GZIPD packer has an open implementation
that Buildroot can run.
