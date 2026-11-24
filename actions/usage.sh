#!/usr/bin/env bash

cat <<EOF
Usage: $0 <command> [options]

Commands:
  start      Download (if needed) and start an Omarchy desktop VM
  stop       Stop a running instance
  status     Show status for an instance (or --all)
  build      Install Omarchy from an ISO into the instance disk
  download   Download Omarchy media for the selected version/arch
  list       Show local instances, cached media, and published 4.x versions
  clean      Erase instance data (stops it first)
  help       Show this message

Options:
  --version VERSION     latest (default) or 4.x.y (Omarchy 4.0+ only)
  --media auto|qcow|iso Media selection (default: auto)
  --instance NAME       Instance name (default: default)
  --cpus N              vCPUs (default: 4)
  --memory MB           RAM in MB (default: 8192)
  --ssh-port PORT       Host SSH forward port (default: auto from 2222)
  --user NAME           Guest username (ISO installs; default: omarchy)
  --password PASS       Guest password (ISO installs; default: omarchy)
  --ssh-key PATH        Private key for guest SSH
  --hostname NAME       Guest hostname (ISO installs)
  --keyboard LAYOUT     Keyboard layout (ISO installs; default: us)
  --timezone TZ         Timezone (ISO installs; default: UTC)
  --disk-size GB        Install disk size in GB (ISO installs; default: 40)
  --display gui|none    Display mode (default: gui)
  --guest-arch ARCH     x86_64 or aarch64 (default: host arch)
  --ephemeral           Discard disk writes when the VM stops
  --force               Recreate the instance even if one already exists
  --all                 Apply to all instances (stop/status/clean)
  --allow-emulation     Allow slow cross-arch TCG

Environment variables with the same names (OMARCHY_BOX_*) are also supported.

Host matrix:
  - Intel Mac / x86_64 Linux: qcow2 happy path (fast)
  - Apple Silicon / aarch64 Linux: ISO install on first run (slower), then reboot from disk
  - Cross-arch guests need --allow-emulation and are slow

Notes:
  - Omarchy 4.0+ only.
  - auto media: qcow2 on x86_64 when published for that version; otherwise ISO.
  - Official qcow2 is typically only available for the current stable latest.
  - Multiple instances can run together; SSH ports are allocated automatically.

EOF

if [[ "${OMARCHY_BOX_USAGE_OK:-}" != "true" ]]; then
  exit 1
fi
