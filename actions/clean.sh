#!/usr/bin/env bash

# Remove the current instance by default. Set OMARCHY_BOX_CLEAN_ALL=true to wipe data/.

if [[ "${OMARCHY_BOX_CLEAN_ALL:-}" == "true" ]]; then
  echo "Removing all Omarchy Box data in ${OMARCHY_BOX_DATA_DIR}…"
  cd "${OMARCHY_BOX_BASE_DIR}"
  rm -rf "${OMARCHY_BOX_DATA_DIR}"
  mkdir -p "${OMARCHY_BOX_DATA_DIR}"
else
  echo "Removing instance '${OMARCHY_BOX_INSTANCE}' at ${OMARCHY_BOX_INSTANCE_DIR}…"
  rm -rf "${OMARCHY_BOX_INSTANCE_DIR}"
  mkdir -p "${OMARCHY_BOX_INSTANCE_DIR}"
fi

cd "${OMARCHY_BOX_DATA_DIR}"
echo "Clean complete."
