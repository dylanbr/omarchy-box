#!/usr/bin/env bash

if [[ "${OMARCHY_BOX_ALL:-}" == "true" ]]; then
  found=false
  shopt -s nullglob
  for dir in "${OMARCHY_BOX_DATA_DIR}/instances"/*; do
    [[ -d "${dir}" ]] || continue
    found=true
    print_instance_status "${dir}"
    echo
  done
  shopt -u nullglob
  if [[ "${found}" != "true" ]]; then
    echo "No instances found."
  fi
else
  print_instance_status
fi
