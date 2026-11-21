# Sipeed NanoKVM-Go

Nerves system for the Sipeed NanoKVM-Go+ (Axera AX620QE, two Cortex-A53 cores
running 32-bit ARM, 512 MiB LPDDR4) on a mainline Linux kernel with open
drivers for its hardware: the HDMI/DisplayPort capture with its sound, the
JPEG and H.264 encoders, the NPU, the LCD and its touch panel. The
NanoKVM-Go with 256 MiB (AX620QF) is not supported yet.

| Feature              | Description                                   |
| -------------------- | --------------------------------------------- |
| CPU                  | 2x Cortex-A53 (AArch32)                       |
| Memory               | 512 MiB                                       |
| Storage              | MicroSD                                       |
| Linux kernel         | 7.3, `cocoa-xu/linux` `cocoa/nerves/ax620e-h264` |
| IEx terminal         | SSH (nerves_ssh)                              |
| Video capture        | V4L2, LT7911EXC bridge, 4K30 YUYV             |
| JPEG encoder         | V4L2 M2M (Hantro VC8000E variant)             |
| H.264 encoder        | V4L2 stateless, 4K30 (VC8000E; see below)     |
| USB gadget           | configfs, NCM at boot, stable MAC addresses   |
| Auxiliary USB-C      | 2 expansion lines: UART, GPIO, PWM or I2C     |
| NPU                  | `ax620e-npu` (axera_npu), 64 MiB pool         |
| WiFi                 | AIC8800D80 (SDIO)                             |
| Watchdog             | Yes, started by U-Boot                        |

## Using it

[Kuroneko](https://github.com/cocoa-xu/kuroneko), the KVM over IP made on
this system, has firmware ready to burn and shows how the parts fit
together. For an application of your own, with `MIX_TARGET=nano_kvm_go`:

```elixir
{:nerves_system_nano_kvm_go,
 github: "cocoa-xu/nerves_system_nano_kvm_go",
 tag: "v0.1.0",
 runtime: false,
 targets: :nano_kvm_go,
 # Until a release carries the prebuilt system: build it with Buildroot,
 # which takes Linux and a while.
 nerves: [compile: true]}
```

The board's hardware is in [`nano_kvm_go`](https://github.com/cocoa-xu/nano_kvm_go),
what the computer sees over USB in
[`kuroneko_gadget`](https://github.com/cocoa-xu/kuroneko_gadget) and the NPU
in [`axera_npu`](https://github.com/cocoa-xu/axera_npu).

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

`Kuroneko.Gadget.set_network_addresses/2`
([`kuroneko_gadget`](https://github.com/cocoa-xu/kuroneko_gadget)) changes
them at once, with this board's options from
[`nano_kvm_go`](https://github.com/cocoa-xu/nano_kvm_go)
(`NanoKVMGo.USB.gadget_options/1`).

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
node. Its buffers come from a pool of its own (`npu-memory`, 64 MiB unless
set otherwise, see below), which movable pages use while the NPU is idle: at
4K the video pipeline holds most of the 192 MiB default CMA. Applications run
models with the `axera_npu` Elixir library.

## Memory for video and the NPU

Video and the NPU take their buffers from contiguous memory (CMA) pools.
U-Boot sizes them at every boot from two variables, in MiB:

| U-Boot variable | Pool                                         | Default (Go+) |
| --------------- | -------------------------------------------- | ------------- |
| `cma_video`     | video's, Linux's default CMA pool            | 192           |
| `cma_npu`       | the NPU's (`npu-memory`); 0 turns the NPU off | 64            |

Sizes are multiples of 8 (Linux aligns CMA pools to its 8 MiB page blocks),
video at least 8, both together at most half of the DRAM. For a variable
that is unset or out of these bounds U-Boot keeps the device tree's size,
and its log says why. Movable pages use what a pool does not hold, so an
idle pool costs little; 4K capture with JPEG and H.264 needs about 192 MiB.
With the NPU off its driver does not bind and its pool goes back to Linux.

```elixir
Nerves.Runtime.KV.put(%{"cma_video" => "160", "cma_npu" => "96"})
```

The sizes apply at the next boot. Trying them first is up to you: set the
new sizes together with the old ones in `cma_video_was` and `cma_npu_was`
(empty for the default) and `cma_try` to `1`. The next boot runs the new
sizes and sets `cma_try` to `2`; validating the firmware
(`Nerves.Runtime.validate_firmware/0`) keeps them, while any boot before
that, after a crash, the watchdog or a plain reboot, puts the old ones back.
`NanoKVMGo.Memory` in [`nano_kvm_go`](https://github.com/cocoa-xu/nano_kvm_go)
does this for you.

Only a full burn writes U-Boot: upgrades keep the card's, and a U-Boot from
before these variables ignores them.

## WiFi firmware

`rootfs_overlay/lib/firmware/aic8800` holds the AIC8800D80 files that the
driver loads, from the NanoKVM-Go firmware v1.0.10 (the same files as in
Sipeed's [`maix_ax620e_sdk`](https://github.com/sipeed/maix_ax620e_sdk)):
the Wi-Fi firmware with Bluetooth coexistence for the chip's U02 and H U02
revisions (built in August 2025), the patches for its ROM and the TX power
settings. AIC allows redistributing it unchanged: see its terms from
linux-firmware in
[LICENSES/LicenseRef-LICENSE.aic.txt](LICENSES/LicenseRef-LICENSE.aic.txt).

linux-firmware's `aic/aic8800d80` cannot replace them yet: it has no
firmware for the H U02 revision, its patches are older (September 2024), and
its TX power settings have a column per region, which this driver reads as
one large number.

## License

Files written for this system are under Apache-2.0. Files from or for
Buildroot, Linux and U-Boot keep their licenses, GPL-2.0-or-later or
GPL-2.0-only, and the boot loaders and the Wi-Fi firmware their vendors'.
[REUSE.toml](REUSE.toml) gives the license of each file and
[LICENSES](LICENSES) their texts.
