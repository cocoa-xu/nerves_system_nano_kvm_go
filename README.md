# Sipeed NanoKVM-Go

Nerves system for the Sipeed NanoKVM-Go (Axera AX620QE, two Cortex-A53 cores
running 32-bit ARM, 512 MiB LPDDR4) on a mainline Linux kernel with open
drivers for the HDMI/DisplayPort capture and the JPEG encoder.

| Feature              | Description                                   |
| -------------------- | --------------------------------------------- |
| CPU                  | 2x Cortex-A53 (AArch32)                       |
| Memory               | 512 MiB                                       |
| Storage              | MicroSD                                       |
| Linux kernel         | 7.3, `cocoa-xu/linux` `cocoa/nerves/ax620e`   |
| IEx terminal         | SSH (nerves_ssh)                              |
| Video capture        | V4L2, LT7911EXC bridge, 4K30 YUYV             |
| JPEG encoder         | V4L2 M2M (Hantro VC8000E variant)             |
| USB gadget           | configfs, NCM + ACM at boot                   |
| WiFi                 | AIC8800D80 (SDIO)                             |
| Watchdog             | Yes, started by U-Boot                        |

## Boot and firmware updates

The boot ROM and the stock SPL load our U-Boot from the boot partition
(`boot/README.md`). U-Boot loads a FIT image (kernel + device tree, sha256)
from a raw slot per side and boots the matching squashfs root filesystem.
Updates write the other side and switch over; an update that reboots
without being validated goes back to the previous side, as on other Nerves
systems (`nerves_fw_autovalidate`). Holding the BOOT button while powering
on boots the other side as well.

Layout and offsets: `fwup_include/fwup-common.conf`.

## USB gadget

`/usr/sbin/nanokvm-init`, which erlinit runs before starting the VM, sets up
the configfs gadget `nanokvm` with an NCM network function (`usb0`) and an
ACM serial function (`ttyGS0`) and binds it. A `VintageNetDirect` config for
`usb0` then reaches the computer the NanoKVM-Go is plugged into, with mDNS.
An application that wants other functions (HID, mass storage) unbinds the
gadget (`UDC`), changes it and binds it again.

## WiFi firmware

`rootfs_overlay/lib/firmware/aic8800` is the AIC8800 firmware shipped with
the NanoKVM-Go firmware v1.0.10.
