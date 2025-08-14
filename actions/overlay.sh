#!/usr/bin/env bash

# Ensure the base image is available and verfied prior to creating the overlay.
run_action verify

# Keep the previous overlay image, should one exist.
if [ -f "${OMARCHY_BOX_OVERLAY_IMAGE}" ]; then
  mv "${OMARCHY_BOX_OVERLAY_IMAGE}" "${OMARCHY_BOX_OVERLAY_IMAGE}.backup"
fi

qemu-img create -f qcow2 -F qcow2 -b ${OMARCHY_BOX_BASE_IMAGE} ${OMARCHY_BOX_OVERLAY_IMAGE}
