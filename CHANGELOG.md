# Changelog

## Unreleased

* `mix compile` builds the system in its own directory: nerves_bootstrap is
  started there, as Nerves 1 needs
* The boot partition is made with Buildroot's own dosfstools and mtools, so
  the build host needs neither

## v0.1.0 (2026-11-21)

Initial release for bring-up.
