#!/usr/bin/env bash

# Remove the current instance by default. Use --all to wipe data/.

if [[ "${OMARCHY_BOX_ALL:-}" == "true" || "${OMARCHY_BOX_CLEAN_ALL:-}" == "true" ]]; then
  echo "Stopping any running instances…"
  shopt -s nullglob
  for dir in "${OMARCHY_BOX_DATA_DIR}/instances"/*; do
    [[ -d "${dir}" ]] || continue
    OMARCHY_BOX_INSTANCE="$(basename "${dir}")"
    OMARCHY_BOX_INSTANCE_DIR="${dir}"
    OMARCHY_BOX_IMAGE="${dir}/disk.qcow2"
    OMARCHY_BOX_SSH_KEY="${dir}/id_ed25519"
    refresh_pidfile_path
    stop_instance >/dev/null 2>&1 || true
  done
  shopt -u nullglob

  echo "Removing all Omarchy Box data in ${OMARCHY_BOX_DATA_DIR}…"
  cd "${OMARCHY_BOX_BASE_DIR}"
  rm -rf "${OMARCHY_BOX_DATA_DIR}"
  mkdir -p "${OMARCHY_BOX_DATA_DIR}"
else
  stop_instance >/dev/null 2>&1 || true
  echo "Removing instance '${OMARCHY_BOX_INSTANCE}' at ${OMARCHY_BOX_INSTANCE_DIR}…"
  rm -rf "${OMARCHY_BOX_INSTANCE_DIR}"
  mkdir -p "${OMARCHY_BOX_INSTANCE_DIR}"
fi

cd "${OMARCHY_BOX_DATA_DIR}"
echo "Clean complete."
