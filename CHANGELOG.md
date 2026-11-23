# Changelog

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
