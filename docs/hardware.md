# NanoKVM Go: hardware and stock boot flow

Notes from probing a NanoKVM Go+ running stock firmware
`nanokvm-go-2026-10-08-v1.0.10`, cross-checked against Sipeed's SDK
([`sipeed/maix_ax620e_sdk`](https://github.com/sipeed/maix_ax620e_sdk) at
`d781b0bc`, kernel submodule `f0c18b62`, msp submodule `71ca5afe`).

## SoC and memory

| | |
| --- | --- |
| SoC | Axera AX620Q (AX620E family). Go+ reports `AX620QE_CHIP`, Go is `AX620QF` |
| CPU | 2x Cortex-A53 (`0xd03`), which the stock firmware runs in **AArch32**: `armv7l`, NEON, VFPv4, idiv, LPAE. This system runs them in AArch64 |
| RAM | Go+ 512 MiB, Go 256 MiB, which the chip type tells. The stock Linux gets `mem=` (352M observed on Go+, 128M on Go); the rest is the CMM pool for the media blocks |
| Board ID | ADC channel 0: `board_id = ((raw - 0x20) / 0x40) + 1`; 1 = 256M, 3 = 512M (raw 192 on Go+) |
| Console | `ttyS3` @ 115200, UART at `0x6080000`; its pads go to the auxiliary USB-C port |

The CMM pool is passed to `ax_cmm.ko` as
`cmmpool=anonymous,0,<0x40000000 + os_mem>,<total - os_mem>M`
(`/soc/scripts/auto_load_all_drv.sh`). On Go+ that is `0x56000000`, 160M.

## Peripherals

| Function | Part | Bus / pins | Driver |
| --- | --- | --- | --- |
| Storage | internal microSD (SDXC 64G on Go+) | `mmc1` = `104e0000.sdhc` -> `mmcblk1` | in-tree |
| eMMC slot | not populated | `mmc0` = `1b40000.sdhc` | |
| Wi-Fi / BT | AIC8800D80 | SDIO `mmc2`, reset GPIO1_A28 | `aic8800_bsp`, `aic8800_fdrv` (source in kernel tree), firmware in `/opt/firmware/aic8800` |
| Video in | Lontium LT7911EXC (4K30) | i2c0 `0x41`, irq GPIO1_A0, reset GPIO1_A1 -> MIPI CSI | `lt7911_manage` (source in kernel tree) + Axera media stack |
| Audio in | LT7911EXC I2S | `i2s_slv` | simple-audio-card |
| LCD | ST7789P3 240x284 (JD9853 alternate) | spi2 @ 80 MHz, DC GPIO1_19, RST GPIO0_31, backlight PWM1 | `fb_st7789p3` (staging fbtft) |
| Touch | Hynitron CST8xx | i2c1 `0x15`, irq GPIO0_2, reset GPIO0_4 | `hynitron_touch` (source in kernel tree) |
| Accelerometer | SC7A20 in DT | i2c0 `0x19` | probe fails (`-121`) on this unit |
| USB | DWC3, device mode | role via extcon GPIO2_A13 | configfs gadget `g0` 359f:3305 = 3x HID + NCM |
| Auxiliary USB-C | USB-PD in, passed on to the target | UART3_TXD/RXD pads; the Finger Robot drives PWM04 on TXD and reads it back on RXD (GPIO1_A3) | `NanoKVM-Server`, through `devmem` |
| Recovery button | | GPIO register `0x600108c` bit 2, active low | read by U-Boot |
| Watchdog | wdt0, wdt2 | | `ax_wdt`, `HANDLE_BOOT_ENABLED` + `NOWAYOUT` |
| RTC | none usable | | |

There is no Ethernet; the network is Wi-Fi (or USB NCM to the target host).

## Storage layout (stock, SD boot)

MBR, the first MiB is empty apart from the MBR itself:

| Part | Type | Size | Content |
| --- | --- | --- | --- |
| p1 | FAT32 `0x0c`, bootable, label `BOOT` | 128 MiB | `boot.bin` (SPL), `uboot.bin`, recovery `kernel.img` + `dtb.img` |
| p2 | ext4, label `rootfs` | rest | Debian 13 armhf rootfs, plus `/boot/kernel.img`, `/boot/dtb.img`, `/boot/configs`, `/boot/ver` |

## Boot chain

1. Boot ROM loads `boot.bin` from the first FAT32 partition. The SPL runs in
   AArch64 and uses FatFs to load `0:uboot.bin` from the same volume.
   Signatures are only enforced when secure boot is fused (unknown on this
   unit, not needed as long as the stock SPL and U-Boot are kept).
2. U-Boot 2020.04 (`AX620Q_emmc_arm32_k419_sipeed_nanoagent_defconfig`)
   runs `sd_boot` (`cmd/axera/sd_boot/sd_boot.c`):
   - bootargs start from the compile-time `BOOTARGS_SD`:
     `mem=... console=... init=/sbin/init root=/dev/mmcblk1p2 rw rootdelay=3 rootfstype=ext4`,
     then console, loglevel and `mem=` are patched from `/boot/configs`
     (`maix_system_console`, `maix_kernel_loglevel`, `maix_memory_cmm`).
   - Normal boot: `ext4load mmc 1:2 /boot/kernel.img` and `/boot/dtb.img`.
     **p2 must be ext4 and must hold these files.**
   - If that fails, or the recovery button is held, it loads `kernel.img` and
     `dtb.img` from FAT p1 instead and appends `boot_key=1`.
   - Images are decompressed by the GZIPD hardware block and booted as an
     arm32 `Image` via `ax_boot_kernel`.
3. The U-Boot environment lives on `mmc 0` (absent), so U-Boot always runs
   with its built-in environment and never writes to the SD card.
4. The kernel has a built-in busybox initramfs
   (`build/projects/.../initramfs/init`). With `boot_key=1`,
   `recovery=1` or `/boot/rec` present it exports **`/dev/mmcblk1p2` only** as
   a USB mass-storage gadget (this is the documented "flashing mode").
   Otherwise it fscks/mounts p2, writes `/device_key` and the first-boot
   hostname, and `switch_root`s to `/sbin/init`.

### `kernel.img` / `dtb.img` format

1024-byte Axera header followed by a GZIPD payload. The payload is not plain
deflate: a 16-byte header (`"20"`, `blk_num`, `osize`, `isize`, `crc32`) and
a proprietary tiled stream. The SDK produces it with:

```sh
tools/ax_gzip_tool/ax_gzip -9 <file>          # closed, static x86_64 Linux binary
python3 build/tools/imgsign/sec_boot_AX620E_sign.py -i <file>_axgzip.bin -o <out> \
  -pub public.pem -prv private.pem -cap 0x54FAFE -key_bit 2048   # SDK default key
```

The SD boot path in U-Boot only reads the size from the header; it does not
verify it.

### Signing and replacing the boot chain

The header holds the RSA-2048 modulus (little-endian at `0x30`) and the
signature (`0x1bc`). All four stock images (`boot.bin`, `uboot.bin`,
`kernel.img`, `dtb.img`) carry the SDK's default public key,
`tools/imgsign/public.pem`, whose private key is published in the same
repository. Whatever the eFuse state, images we build and sign with that key
are accepted, so the SPL and U-Boot can be rebuilt from the SDK and replaced.
Secure boot is controlled by bit 26 of `COMM_SYS_BOND_OPT` (`0x02340098`).

Every boot stage lives on the removable microSD card, so a bad boot chain is
fixed by rewriting the card in a card reader.

## Kernel

- Linux 4.19.125 from
  [`sipeed/maix_ax620e_sdk_kernel`](https://github.com/sipeed/maix_ax620e_sdk_kernel),
  `arch/arm/configs/axera_AX620Q_emmc_arm32_k419_sipeed_nanoagent_defconfig`,
  `arch/arm/boot/dts/axera/AX620Q_emmc_arm32_k419_sipeed_nanoagent.dts`.
- Built with Arm GNU Toolchain 10.3-2021.07 `arm-none-linux-gnueabihf`.
- Thumb-2 kernel, `VMSPLIT_3G`, `PREEMPT`, `HZ=100`, `NR_CPUS=2`, no
  `HIGHMEM`, no `IKCONFIG`. Already has SquashFS (XZ, LZO), devtmpfs
  automount, the configfs gadget functions, cfg80211/mac80211, BT, zram.
- **The media drivers (`ax_sys`, `ax_cmm`, `ax_pool`, `ax_venc`, `ax_proton`,
  `ax_npu`, ...) are binary-only** (`osdrv/out/arm_glibc_linux-4.19.125/ko`)
  with vermagic `4.19.125 SMP preempt mod_unload ARMv7 thumb2 p2v8`.
  The kernel cannot move off 4.19.125, and config changes must not alter
  structure layouts those modules depend on.
- Everything else out of tree (aic8800, lt7911_manage, hynitron touch,
  st7789p3) has source in the kernel tree.

### Media stack notes (for open drivers)

- A KVM only needs the MIPI CSI-2 receiver (`ax_mipi_rx`, `ax_mipi_switch`),
  the YUV bypass capture path inside the ISP driver `ax_proton`, and the
  VeriSilicon encoders (`ax_venc` for H.264/H.265, `ax_jenc` for JPEG). ISP
  tuning, NPU, GDC and IVE are not on that path.
- None of the `ax_*.ko` are stripped. `ax_mipi_rx` has 114 named functions
  (`ax_dphyrx_glb_init`, `ax_mipi_rx_csi_ctrl_init`, ...), `ax_proton` has
  3283 (including `__ax_bypass_pipe_wait_yuv_irq_event`), and `ax_venc` /
  `ax_jenc` wrap VeriSilicon's VCMD kernel driver (`hantroenc_vcmd_*`,
  `hantrovcmd_isr`).
- Register blocks: encoder `vsi_vcx` at `0x04010000`, JPEG `ax_jenc` at
  `0x04000000`, decoder `hx170dec0` at `0x04020000`.
- Mainline `drivers/media/platform/verisilicon` only encodes JPEG (H1/VPU2);
  there is no VC8000E or H.264/H.265 encoder upstream.
- The modules map their registers through `AX_OSAL_DEV_ioremap_nocache`, and
  OSAL is source, so their register accesses can be logged mmiotrace-style
  from a rebuilt 4.19 kernel. Turning on FTRACE (and likely KPROBES) is not an
  option: it changes `struct module`, which breaks the prebuilt modules.

## Stock userspace

Debian 13 armhf with systemd, glibc 2.41. The KVM app is closed source for
now ([`sipeed/NanoKVM-Go`](https://github.com/sipeed/NanoKVM-Go) only holds a
license file):

- `NanoKVM-Server` (Go), `kvm_vin` (capture/encode), `kvm_ui` (LCD UI),
  supervised by `/kvmcomm/scripts/kvmcomm.sh` and `/kvmapp/scripts/nanokvm.sh`.
- Media libraries in `/opt/lib` (`libax_*.so`, glibc). `kvm_vin` also links
  Debian's FFmpeg 7 stack.
- `kvmcomm/scripts/firmware_update.sh` updates `uboot.bin` on p1 and
  `kernel.img`/`dtb.img` under p2 `/boot` from signed packages on Sipeed's CDN.

The stock aic8800 driver prints Wi-Fi session keys to the kernel log on every
association.

## Implications for Nerves

1. **Toolchain.** The current Nerves armv7 glibc toolchain (v15.3.1: GCC 15.3,
   glibc 2.43, Linux 6.0.12 headers, so glibc is built with
   `--enable-kernel=6.0.12`) does not run on this kernel. A test binary
   aborts immediately with `The futex facility returned an unexpected error
   code.` because glibc calls `futex_time64` unconditionally. Nerves on this
   device needs a toolchain built against Linux 4.19 headers. musl is not an
   option because the media libraries are glibc-linked.
2. **Kernel.** Build Sipeed's 4.19.125 tree with the vendor defconfig plus
   ABI-neutral additions only (root/cmdline handling, filesystem and
   compression options).
3. **Bootloader.** Keeping the stock `boot.bin` and `uboot.bin` is the low-risk
   path. The constraints that follow:
   - p1 stays FAT32, first in the MBR, and holds `boot.bin` and `uboot.bin`.
   - p2 is ext4 with `/boot/kernel.img` and `/boot/dtb.img`.
   - bootargs always say `root=/dev/mmcblk1p2 rootfstype=ext4 rw`, so the
     kernel has to override them, for example with `CMDLINE_EXTEND`, since the
     last `root=`/`rootfstype=`/`ro` wins.
4. **A/B.** An MBR-swap layout in the style of `nerves_system_rpi` fits these
   constraints: p1 FAT (stock loaders), p2 small ext4 boot (A/B), p3 squashfs
   rootfs (A/B), p4 application data. An upgrade writes the inactive copies and
   then rewrites the MBR.
5. **64-bit.** The cores are ARMv8-A; AArch32 is only Sipeed's BSP choice
   (the SPL itself runs in AArch64). The SDK carries the arm64 BSP for the
   AX630C sibling (SPL + ATF + U-Boot + 4.19.125 arm64 kernel, prebuilt arm64
   media modules and libraries), and U-Boot ships `AX620Q_*_arm64_k515`
   defconfigs, so Axera supports AX620Q in AArch64. Running the Go in
   AArch64 needs an arm64 SPL/ATF/U-Boot build for this board and an arm64
   port of the DTS. The AX630C-built media modules are unverified on AX620Q.
   The gain is the BEAM JIT (x86_64 and aarch64 only); the cost is memory,
   which matters most on the 256M Go. Done another way: the stock SPL and our
   U-Boot stay AArch32, and U-Boot's `go64` warm-resets the cores into
   AArch64 and enters the SDK's TF-A BL31 (`boot/README.md`).
6. **Recovery.** Stock flashing mode only exports p2. The first install, and
   any later "flash the whole card over USB", needs a kernel+initramfs that
   exports all of `/dev/mmcblk1`, booted either from p2 (installer) or from
   p1 (replacement recovery kernel).
