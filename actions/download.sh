#!/usr/bin/env bash

ensure_runtime_dependencies
download_resolved_media
echo "Media ready."
if [[ "${OMARCHY_BOX_MEDIA_KIND}" == "qcow" ]]; then
  echo "Base image: ${OMARCHY_BOX_BASE_IMAGE}"
else
  echo "ISO: ${OMARCHY_BOX_ISO}"
fi
