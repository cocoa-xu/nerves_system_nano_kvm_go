# Changelog

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
