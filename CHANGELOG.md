# Changelog

## v0.2.0 (2026-11-28)

* Cached encoder bitstream buffers with synchronization limited to the bytes
  written, matching the low-latency pipeline validated on the device
* Clear encoder state when switching H.264 and H.265, preventing stale
  H.265 data from becoming an H.264 rate-control callback pointer
* Include package patches in the system archive and build fingerprint

* AArch64: Linux and the BEAM run in 64 bits, the BEAM with its JIT (Elixir
  code ran 2.4 to 6.5 times as fast in our measurements), on the Nerves
  aarch64 toolchain. U-Boot (u-boot-ax620e e16d8c64) boots the slot's FIT
  image, now Linux's Image.gz, its device tree and TF-A's BL31 (boot/README.md),
  through its new `go64` command, which warm-resets the cores into AArch64
  and enters BL31; BL31 starts the second core (PSCI) and keeps its 256 KiB
  at 0x40040000. A card needs a full burn: upgrades from the 32-bit system
  refuse firmware of another architecture, and would keep the old U-Boot
* Linux at linux-ax620e 1bb2b65:
  * Bluetooth: the AIC8800's controller as an HCI device, its packets
    carried in the Wi-Fi firmware's SDIO messages (the firmware the system
    loads is the one built for that), with RFCOMM, HIDP, BNEP and UHID, and
    drivers for Bluetooth keyboards, mice and game controllers (Apple,
    Microsoft, PlayStation, Nintendo)
  * CPU frequency scaling: the cores run at 208 MHz, 500 MHz, 800 MHz or
    1.2 GHz, which the boot firmware had fixed at 1.2 GHz, chosen by the
    `ondemand` governor; an idle KVM spends most of its time at 208 MHz
  * The HDMI bridge converts the picture to BT.601 or BT.709 at the full or
    the limited range, as the capture is asked with
    `V4L2_PIX_FMT_FLAG_SET_CSC` (it gave BT.709 at full range only), and
    the capture reports the colour it delivers; by default its firmware's
    own, BT.709 at full range, also after a reboot that left another
* BlueZ 5.86 (bluetoothd, bluetoothctl, btmon), D-Bus and bluez-alsa. BlueZ
  keeps the subscriptions of bonded devices to notifications (our patch: it
  kept only Service Changed's), so a phone paired with an HID device made
  of the board gets its input again after a restart. `nanokvm-init`
  prepares the machine ID and the system bus's directory; an application
  starts `dbus-daemon` and `bluetoothd` and keeps the pairings on the data
  partition, as nano_kvm_go's `NanoKVMGo.Bluetooth` does (it binds
  `/data/bluetooth` onto `/var/lib/bluetooth`)
* The NPU driver at axera_npu 55dd263: programs and tasks with 64-bit user
  pointers besides the vendor's interface, which the runtime of that
  version needs, and 32-bit processes on a 64-bit kernel

## v0.1.4 (2026-11-27)

* The NanoKVM-Go with 256 MiB as well as the Go+ with 512 MiB, from the same
  card: U-Boot knows the DRAM in the chip's package and gives it to Linux
  (its own memory fixup, which the vendor's configuration had turned off),
  with the CMA pools of that board, 128 MiB for video and the NPU off on
  the Go. Sizes set in `cma_video` and `cma_npu` that do not fit the board
  give the board's, and they leave Linux at least 96 MiB (was: half of the
  DRAM). Linux no longer takes 512 MiB whatever the board, and the RAM log
  of early boot messages moved to 0x4ff00000, in the DRAM of both. A card
  needs a full burn for this U-Boot: upgrades keep the card's
* U-Boot at u-boot-ax620e be209481 takes commands of up to 32 arguments
  (was 16), and `nerves_try` passes the kernel arguments to `setenv` as one:
  a `cmdline` of more than a few words no longer fails the boot
* Linux at linux-ax620e 50a3346:
  * H.265 (HEVC) encoding on the VENC, next to H.264
  * The RAM log's reserved memory within the first 256 MiB

## v0.1.3 (2026-11-23)

* Linux at linux-ax620e 7af4e54:
  * The USB gadget's optical drive takes CDs whose image keeps the sectors
    as the disc has them, as a CUE sheet's BIN does: audio tracks and data
    tracks of mode 1 and 2, from the LUN's `tracks`. It answers READ TOC
    for each track, READ CD for audio and whole sectors with their
    subchannel, and READ SUB-CHANNEL
  * It tells the target of a new or a removed disc by GET EVENT STATUS
    NOTIFICATION, and asks it to eject a disc, as a drive's button does
    (the LUN's `eject_request`)
* UDF and ISO 9660 in the kernel, and `losetup` in BusyBox: the device can
  read an installer ISO's files and lay disk images out from them

## v0.1.2 (2026-11-23)

* Unix datagram sockets queue 512 messages, as on desktop distributions,
  not the kernel's 10: after a Wi-Fi scan, wpa_supplicant no longer drops
  the socket VintageNet hears it on, which froze the list of networks
* exFAT in the kernel, and exfatprogs (`mkfs.exfat`, `fsck.exfat`), for
  drives with files over 4 GiB
* Linux at linux-ax620e 1d958d8:
  * The USB gadget's optical drive holds DVDs and BDs as well as CDs (the
    LUN's `profile`), answers GET CONFIGURATION, READ DISC STRUCTURE, READ
    DISC and TRACK INFORMATION and READ CD, and no longer cuts images at
    2.3 GB
  * Wi-Fi (AIC8800): the TCP ACK filter holds back pure ACKs only, never
    duplicate, SACK, FIN or RST ones nor a new connection's; reorder frames
    go back to their pool on errors; late frames are dropped for RTP only;
    no kernel log line each second for the TX power

## v0.1.1 (2026-11-23)

* `mix compile` builds the system in its own directory: nerves_bootstrap is
  started there, as Nerves 1 needs
* The boot partition is made with Buildroot's own dosfstools and mtools, so
  the build host needs neither
* The application data partition grows to the end of the card at boot, also
  on cards written from an image (balenaEtcher, dd): fwup grew it only when
  writing the card itself. An f2fs made before is made again over the whole
  partition, its files copied through memory

## v0.1.0 (2026-11-21)

Initial release for bring-up.
