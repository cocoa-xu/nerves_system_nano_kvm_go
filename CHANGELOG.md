# Changelog

## Unreleased

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
