#!/usr/bin/env bash

# Force an ISO install into the current instance disk.
OMARCHY_BOX_MEDIA=iso
OMARCHY_BOX_FORCE=true

ensure_runtime_dependencies
ensure_instance_ssh_key
download_resolved_media

if [[ "${OMARCHY_BOX_MEDIA_KIND}" != "iso" ]]; then
  echo "build requires ISO media." >&2
  exit 1
fi

rm -f "${OMARCHY_BOX_IMAGE}" "${OMARCHY_BOX_INSTANCE_DIR}/.ready" "${OMARCHY_BOX_INSTANCE_DIR}/.media"
prepare_iso_instance
boot_instance
