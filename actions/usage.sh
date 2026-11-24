#!/usr/bin/env bash

cat <<EOF
Usage: $0 <command> [options]

Commands:
  start      Download (if needed) and start an Omarchy desktop VM
  build      Install Omarchy from an ISO into the instance disk
  download   Download Omarchy media for the selected version/arch
  list       Show local instances, cached media, and published 4.x versions
  clean      Erase instance data and start fresh
  help       Show this message

Options:
  --version VERSION     latest (default) or 4.x.y (Omarchy 4.0+ only)
  --media auto|qcow|iso Media selection (default: auto)
  --instance NAME       Instance name (default: default)
  --cpus N              vCPUs (default: 4)
  --memory MB           RAM in MB (default: 8192)
  --ssh-port PORT       Host SSH forward port (default: 2222)
  --user NAME           Guest username (ISO installs; default: omarchy)
  --password PASS       Guest password (ISO installs; default: omarchy)
  --ssh-key PATH        Private key for guest SSH
  --hostname NAME       Guest hostname (ISO installs)
  --keyboard LAYOUT     Keyboard layout (ISO installs; default: us)
  --timezone TZ         Timezone (ISO installs; default: UTC)
  --disk-size GB        Install disk size in GB (ISO installs; default: 40)
  --display gui|none    Display mode (default: gui)
  --guest-arch ARCH     x86_64 or aarch64 (default: host arch)
  --force               Recreate the instance even if one already exists
  --allow-emulation     Allow slow cross-arch TCG

Environment variables with the same names (OMARCHY_BOX_*) are also supported.

Notes:
  - Omarchy 4.0+ only.
  - auto media: qcow2 on x86_64 when published for that version; otherwise ISO.
  - Official qcow2 is typically only available for the current stable latest.
  - macOS and Linux hosts are supported.

EOF

if [[ "${OMARCHY_BOX_USAGE_OK:-}" != "true" ]]; then
  exit 1
fi
