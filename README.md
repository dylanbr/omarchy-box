# Omarchy Box

> [!WARNING]
> Omarchy Box is a work in progress. It is not yet ready for production use, and the interface may change without notice. It is currently being rewritten for Omarchy 4.0+; the old online installer path is gone.

Build and run [Omarchy](https://omarchy.org/) in a virtual machine to try the desktop, test releases, or explore without affecting your main system.

## Requirements

Omarchy Box supports **macOS and Linux**. Windows is not supported yet.

Guest architecture matches the host by default:
- Intel Mac / x86_64 Linux → x86_64 guest (official qcow2 happy path)
- Apple Silicon / aarch64 Linux → aarch64 guest (official ISO install; no official aarch64 qcow yet)

Cross-arch emulation is opt-in and slow (`OMARCHY_BOX_ALLOW_EMULATION=true`).

Dependencies:
- `qemu` (`qemu-system-x86_64` and/or `qemu-system-aarch64`, plus `qemu-img`)
- UEFI firmware (bundled with Homebrew `qemu`; on Linux install `ovmf` / `qemu-efi-aarch64`)
- `curl`, `ssh`, `scp`, `python3`, `openssl`
- For ISO installs: a way to build cidata (`hdiutil` on macOS, or `dosfstools`+`mtools`, or `xorriso`/`genisoimage`)
- Optional: `sshpass` (password SSH fallback only; keys preferred)

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

On first run this downloads the latest stable Omarchy media and boots a desktop VM:
- **x86_64:** official qcow2 (fast)
- **aarch64:** unattended ISO install via cidata (slower first run)

```bash
./omarchy-box download   # fetch media only
./omarchy-box build      # force ISO install into the instance disk
./omarchy-box clean      # reset the current instance
```

Login defaults to user/password `omarchy` / `omarchy`. SSH uses a per-instance key under `data/instances/<name>/`.

### Environment Variables

- `OMARCHY_BOX_CPUS` — vCPUs (default: 4)
- `OMARCHY_BOX_RAM` — RAM in MB (default: 8192)
- `OMARCHY_BOX_SSH_PORT` — host SSH forward port (default: 2222)
- `OMARCHY_BOX_INSTANCE` — instance name (default: `default`)
- `OMARCHY_BOX_GUEST_ARCH` — `x86_64` or `aarch64` (default: host arch)
- `OMARCHY_BOX_MEDIA` — `auto`, `qcow`, or `iso` (default: `auto`)
- `OMARCHY_BOX_DISPLAY` — `gui` or `none` (default: `gui`)
- `OMARCHY_BOX_DISK_GB` — disk size for ISO installs (default: 40)
- `OMARCHY_BOX_SSH_KEY` — private key for guest SSH
- `OMARCHY_BOX_SSH_USER` / `OMARCHY_BOX_SSH_PASS` — defaults `omarchy` / `omarchy`

## License

Omarchy Box is released under the [MIT License](https://opensource.org/licenses/MIT).
