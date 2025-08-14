#!/usr/bin/env bash

# Ensure the image has been downloaded
run_action download

sha256sum -c ${OMARCHY_BOX_BASE_IMAGE}.SHA256
