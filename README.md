# Vlarch

*Just, Vlad's Arch.*

A personal Arch Linux flavor, installed in one command from a fresh Arch live USB.

## Install

Boot a fresh [Arch Linux live ISO](https://archlinux.org/download/), then run:

```sh
curl -fsSL 'https://vlarch.vladi.tech/install.sh' | bash
```

Answer the prompts. The installer partitions the target disk, encrypts it with LUKS, installs a minimal base (`pacstrap.txt`), bootstraps `yay`, and reboots into autologin. On first login, `vlarch first-boot` brings up networking and runs a full `vlarch update` (packages, dotfiles, desktop).

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

- `vlarch update` — full system update: `pacman -Syu`, sync manifest packages, dotfiles, hyprpm, and refresh the CLI.
- `vlarch post-install` — re-run idempotent finalization (NetworkManager, WiFi).
- `vlarch version` — print install metadata.
- `vlarch help` — list all subcommands.

Update also works without the CLI:

```sh
curl -fsSL 'https://vlarch.vladi.tech/update.sh' | bash
```

The bootstrap compares your installed `version=` (written on first update) against `https://vlarch.vladi.tech/version.txt` and skips when already up to date. Fresh installs have no version until the first update completes. Use `--force` to re-run anyway.

Package manifests live under `update/packages/`; dotfiles live at `dotfiles/` in the repo root. Install embeds the pacstrap list in `install/steps/04_pacstrap.sh` and seeds `install/assets/.zprofile` before the first update.

Optional flags:

```sh
vlarch update --dry-run --verbose
vlarch update --force
```

## Philosophy

- **Personal first.** Built for my machines. If you use it, you adopt my taste.
- **Clean.** No bloat. Every package has a reason.
- **Pure Arch.** Rolling Arch packages managed through `yay`.
- **One door in.** A single `install.sh` from a live USB. A single `vlarch` CLI after — including `vlarch update`.

## License

GPL.
