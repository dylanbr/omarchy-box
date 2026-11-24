#!/usr/bin/env bash

if [[ "${OMARCHY_BOX_ALL:-}" == "true" ]]; then
  shopt -s nullglob
  for dir in "${OMARCHY_BOX_DATA_DIR}/instances"/*; do
    [[ -d "${dir}" ]] || continue
    OMARCHY_BOX_INSTANCE="$(basename "${dir}")"
    OMARCHY_BOX_INSTANCE_DIR="${dir}"
    OMARCHY_BOX_IMAGE="${dir}/disk.qcow2"
    OMARCHY_BOX_SSH_KEY="${dir}/id_ed25519"
    refresh_pidfile_path
    stop_instance
  done
  shopt -u nullglob
else
  stop_instance
fi
