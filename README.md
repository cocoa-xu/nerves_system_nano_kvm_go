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
| H.264 encoder        | V4L2 stateless, 4K30 (VC8000E; see below)     |
| USB gadget           | configfs, NCM at boot, stable MAC addresses   |
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
the configfs gadget `nanokvm` with an NCM network function (`usb0`) and
binds it. A `VintageNetDirect` config for `usb0` then reaches the computer
the NanoKVM-Go is plugged into, with mDNS. There is no serial (ACM)
function: the KVM functions need all seven of the controller's endpoints
for data to the computer. An application that wants other functions (HID,
mass storage, audio) unbinds the gadget (`UDC`), changes it and binds it
again.

The network function keeps its MAC addresses from boot to boot, so that
the computer keeps one network interface for the NanoKVM-Go instead of
finding a new one each time:

| U-Boot variable   | Address of                              | Default                     |
| ----------------- | --------------------------------------- | --------------------------- |
| `usbnet_devaddr`  | the NanoKVM-Go's end (`usb0`)           | bytes 0-5 of SHA-256(ID)    |
| `usbnet_hostaddr` | the computer's end, its network adapter | bytes 6-11 of SHA-256(ID)   |

The ID is the serial number `boardid` prints (the hostname's suffix), and
the defaults are locally administered unicast addresses. Set a variable to
choose an address, and leave it empty for the default; the change applies
at the next boot:

```elixir
Nerves.Runtime.KV.put("usbnet_hostaddr", "02:12:34:56:78:9a")
```

The `nano_kvm` library changes them at once with
`NanoKVM.USB.set_network_addresses/3`.

## H.264 encoder

The kernel carries the V4L2 H.264 stateless encode series for the VC8000E
(posted to linux-media in May 2026, not merged upstream yet) with the
AX620E variant on top, so its uAPI (`V4L2_CID_STATELESS_H264_ENCODE_PARAMS`)
may still change. The encoder writes `frame_num` and `pic_order_cnt_lsb`
with 16 bits whatever is configured; the driver declares that in the SPS,
and applications must wrap their counters at 2^16.

## WiFi firmware

`rootfs_overlay/lib/firmware/aic8800` is the AIC8800 firmware shipped with
the NanoKVM-Go firmware v1.0.10.
