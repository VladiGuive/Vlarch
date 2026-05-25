# Vlarch

*Just, Vlad's Arch.*

A personal Arch Linux flavor, installed in one command from a fresh Arch live USB.

## Install

Boot a fresh [Arch Linux live ISO](https://archlinux.org/download/), then run:

```sh
curl -fsSL 'https://vlarch.vladi.tech/install.sh' | bash
```

Answer the prompts. The installer partitions the target disk, encrypts it with LUKS, installs the Vlarch package set, applies dotfiles, and reboots into an autologin Hyprland session.

Optional flags:

```sh
curl -fsSL 'https://vlarch.vladi.tech/install.sh' | bash -s -- --dry-run --verbose
```

## Live USB note

The Arch live ISO keeps writable state on a RAM-backed overlay at `/run/archiso/cowspace`, not on the USB. If RAM is tight, edit GRUB at boot and append:

```
cow_spacesize=75%
```

The installer's preflight step also remounts cowspace to 75% automatically when free space is low.

## After install

The installed system ships a `vlarch` CLI. Useful commands:

- `vlarch post-install` — re-run idempotent finalization (NetworkManager, baseline snapshot, Hyprland plugins).
- `vlarch version` — print install metadata.
- `vlarch help` — list all subcommands.

## Philosophy

- **Personal first.** Built for my machines. If you use it, you adopt my taste.
- **Clean.** No bloat. Every package has a reason.
- **Pure Arch.** Rolling Arch packages managed through `yay`.
- **One door in.** A single `install.sh` from a live USB. A single `vlarch` CLI after.

## License

GPL.
