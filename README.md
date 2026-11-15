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
| Auxiliary USB-C      | 2 expansion lines: UART, GPIO, PWM or I2C     |
| NPU                  | `ax620e-npu` (axera_npu), 64 MiB pool         |
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
`NanoKVM.USB.set_network_addresses/2`.

## Auxiliary USB-C port

Besides USB-PD power, the port with the lightning icon carries two SoC
pads, UART3's TXD and RXD, which Sipeed's Finger Robot uses. The system
makes them expansion lines for the application. There is no USB on this
port: the SoC's only USB controller is the main port's.

Nothing uses UART3 as a console. U-Boot does not wait for a key there
(`bootdelay=-2`), Linux's console is `ttynull` (early messages go to the RAM
log) and so is the Erlang VM's terminal: use SSH. The boot ROM and the stock
SPL may still print a few lines on TXD at power-on.

The `nanokvm-go-expansion` driver keeps both lines as inputs pulled down
until the application writes a mode to `/sys/devices/platform/expansion/mode`
(`modes` lists them):

| Mode       | Line 0 (TXD pad)              | Line 1 (RXD pad)              |
| ---------- | ----------------------------- | ----------------------------- |
| `off`      | input, pulled down (at boot)  | input, pulled down            |
| `uart`     | `ttyS3` TXD                   | `ttyS3` RXD                   |
| `gpio`     | GPIO `EXPANSION0`             | GPIO `EXPANSION1`             |
| `pwm`      | `6061000.pwm` channel 0       | `6061000.pwm` channel 1       |
| `pwm-gpio` | `6061000.pwm` channel 0       | GPIO `EXPANSION1`             |
| `gpio-pwm` | GPIO `EXPANSION0`             | `6061000.pwm` channel 1       |
| `i2c`      | `/dev/i2c-2` SDA, pulled up   | `/dev/i2c-2` SCL, pulled up   |

What a mode does not give to userspace stays requested by the driver, so
nothing drives a line by mistake; a mode is left only once the application
has let go of its GPIOs and PWM channels (`EBUSY` until then). The I2C bus
is bit-banged at about 50 kHz and counts on the module's pull-ups, the
pads' own are weak.

Not known yet: which USB-C contacts carry the lines (SBU1/SBU2 or D+/D-; on
SBU, flipping the plug swaps line 0 and line 1) and the pads' voltage, most
likely 3.3 V. Measure before connecting anything other than the Finger
Robot.

## H.264 encoder

The kernel carries the V4L2 H.264 stateless encode series for the VC8000E
(posted to linux-media in May 2026, not merged upstream yet) with the
AX620E variant on top, so its uAPI (`V4L2_CID_STATELESS_H264_ENCODE_PARAMS`)
may still change. The encoder writes `frame_num` and `pic_order_cnt_lsb`
with 16 bits whatever is configured; the driver declares that in the SPS,
and applications must wrap their counters at 2^16.

## NPU

The `ax620e-npu` driver comes from
[axera_npu](https://github.com/cocoa-xu/axera_npu) (the `axera-npu`
package, pinned to a commit) and loads at boot from the NPU's device tree
node. Its buffers come from a 64 MiB pool of its own (`npu-memory`), which
movable pages use while the NPU is idle: at 4K the video pipeline holds most
of the 192 MiB default CMA. Applications run models with the `axera_npu`
Elixir library.

## WiFi firmware

`rootfs_overlay/lib/firmware/aic8800` is the AIC8800 firmware shipped with
the NanoKVM-Go firmware v1.0.10.
