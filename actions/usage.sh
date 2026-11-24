#!/usr/bin/env bash

cat <<EOF
Usage: $0 <command>

Primary Commands:
  start      Download (if needed) and start an Omarchy desktop VM
  build      Install Omarchy from an ISO into the instance disk
  download   Download Omarchy media for this host/guest arch

Other Commands:
  clean      Erase instance/data and start fresh
  help       Show this message

Environment (common):
  OMARCHY_BOX_CPUS          vCPUs (default: 4)
  OMARCHY_BOX_RAM           RAM in MB (default: 8192)
  OMARCHY_BOX_SSH_PORT      Host SSH port (default: 2222)
  OMARCHY_BOX_INSTANCE      Instance name (default: default)
  OMARCHY_BOX_GUEST_ARCH    x86_64 | aarch64 (default: host arch)
  OMARCHY_BOX_MEDIA         auto | qcow | iso (default: auto)
  OMARCHY_BOX_DISPLAY       gui | none (default: gui)
  OMARCHY_BOX_SSH_KEY       Private key for guest SSH (auto-generated if unset)
  OMARCHY_BOX_DISK_GB       Install disk size for ISO installs (default: 40)
  OMARCHY_BOX_ALLOW_EMULATION=true
                            Allow slow cross-arch TCG (not recommended)

Notes:
  - Omarchy 4.0+ only (no online installer, no bare mode).
  - auto media: qcow2 on x86_64 when published; ISO install on aarch64.
  - macOS and Linux hosts are supported.

EOF

if [[ "${OMARCHY_BOX_USAGE_OK:-}" != "true" ]]; then
  exit 1
fi
