# Omarchy Box

> [!WARNING]
> Omarchy Box is a work in progress. It is not yet ready for production use, and the interface may change without notice. It is currently being rewritten for Omarchy 4.0+; the old online installer path is gone.

Build and run [Omarchy](https://omarchy.org/) in a virtual machine to try the desktop, test releases, or explore without affecting your main system.

## Requirements

Omarchy Box supports **macOS and Linux**. Windows is not supported yet.

| Host | Guest (default) | Happy path |
|---|---|---|
| Intel Mac / x86_64 Linux | x86_64 | Official qcow2 (fast) |
| Apple Silicon / aarch64 Linux | aarch64 | Official ISO install first, then persistent disk |
| Cross-arch | opt-in | `--allow-emulation` (TCG, slow) |

Dependencies:
- `qemu` (`qemu-system-x86_64` and/or `qemu-system-aarch64`, plus `qemu-img`)
- UEFI firmware (bundled with Homebrew `qemu`; on Linux install `ovmf` / `qemu-efi-aarch64`)
- `curl`, `ssh`, `scp`

ISO installs only (aarch64 happy path, or `build` / `--media iso`):
- `openssl` (to hash the user password)
- a way to build cidata (`hdiutil` on macOS — already present; on Linux `dosfstools`+`mtools`, or `xorriso`/`genisoimage`)

Optional: `sshpass` (password SSH fallback only; keys preferred)

On some hosts, like Ubuntu, `qemu` doesn't install any systems by default. In that case an additional package like `qemu-system-x86` (and `qemu-system-arm` on aarch64 hosts) is required for the `qemu-system-*` commands to be available. Other hosts, like macOS with Homebrew, installing `qemu` is sufficient to get the system emulators and firmware.

## Installation

```bash
git clone https://github.com/dylanbr/omarchy-box.git
cd omarchy-box
```

## Usage

```bash
./omarchy-box start
```

On first run this downloads the latest stable Omarchy media and boots a desktop VM.

```bash
./omarchy-box start --instance lab --version 4.5.0
./omarchy-box start --instance try --ephemeral
./omarchy-box status --instance lab
./omarchy-box stop --instance lab
./omarchy-box stop --all
./omarchy-box list
./omarchy-box build --version 4.0.6 --media iso --hostname lab
./omarchy-box clean --instance lab
```

Login defaults to user/password `omarchy` / `omarchy`. SSH uses a per-instance key under `data/instances/<name>/`. SSH ports default to `2222` and auto-increment when that port is busy so multiple instances can run together.

### Common options

| Option | Purpose |
|---|---|
| `--version latest\|4.x.y` | Omarchy release (4.0+ only) |
| `--media auto\|qcow\|iso` | Prefer qcow, force ISO, or auto |
| `--instance NAME` | Named instance directory |
| `--cpus N` / `--memory MB` | VM size |
| `--ssh-port PORT` | Fixed host SSH port (otherwise auto) |
| `--ephemeral` | Discard disk writes when the VM stops |
| `--force` | Recreate an existing instance |
| `--all` | Apply to every instance (`stop` / `status` / `clean`) |

Equivalent `OMARCHY_BOX_*` environment variables are also supported.

## License

Omarchy Box is released under the [MIT License](https://opensource.org/licenses/MIT).
