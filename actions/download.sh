#!/usr/bin/env bash

if [ ! -f "${OMARCHY_BOX_BASE_IMAGE}" ]; then
  curl -fSLO "https://geo.mirror.pkgbuild.com/images/latest/${OMARCHY_BOX_BASE_IMAGE}"
  curl -fSLO "https://geo.mirror.pkgbuild.com/images/latest/${OMARCHY_BOX_BASE_IMAGE}.SHA256"
fi
