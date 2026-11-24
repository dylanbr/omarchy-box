#!/usr/bin/env bash

# Create a qcow2 overlay backed by a base image.
# Usage (sourced): set OMARCHY_BOX_BASE_IMAGE and OMARCHY_BOX_IMAGE first.

ensure_runtime_dependencies

if [[ -z "${OMARCHY_BOX_BASE_IMAGE:-}" ]]; then
  echo "OMARCHY_BOX_BASE_IMAGE is not set." >&2
  exit 1
fi

if [[ ! -f "${OMARCHY_BOX_BASE_IMAGE}" ]]; then
  echo "Base image not found: ${OMARCHY_BOX_BASE_IMAGE}" >&2
  exit 1
fi

mkdir -p "$(dirname "${OMARCHY_BOX_IMAGE}")"

if [[ -f "${OMARCHY_BOX_IMAGE}" ]]; then
  mv "${OMARCHY_BOX_IMAGE}" "${OMARCHY_BOX_IMAGE}.backup"
fi

qemu-img create -f qcow2 -F qcow2 -b "${OMARCHY_BOX_BASE_IMAGE}" "${OMARCHY_BOX_IMAGE}"
