# Changelog

## Unreleased

* Linux at linux-ax620e cc5e212:
  * CPU frequency scaling: the cores run at 208 MHz, 500 MHz, 800 MHz or
    1.2 GHz, which the boot firmware had fixed at 1.2 GHz, chosen by the
    `ondemand` governor; an idle KVM spends most of its time at 208 MHz
  * The HDMI bridge converts the picture to BT.601 or BT.709 at the full or
    the limited range, as the capture is asked with
    `V4L2_PIX_FMT_FLAG_SET_CSC` (it gave BT.709 at full range only), and
    the capture reports the colour it delivers; by default its firmware's
    own, BT.709 at full range, also after a reboot that left another

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
