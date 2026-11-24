#!/usr/bin/env bash

# Force an ISO install into the current instance disk.
OMARCHY_BOX_MEDIA=iso

ensure_runtime_dependencies
ensure_instance_ssh_key
download_resolved_media

if [[ "${OMARCHY_BOX_MEDIA_KIND}" != "iso" ]]; then
  echo "build requires ISO media." >&2
  exit 1
fi

prepare_iso_instance
boot_instance
