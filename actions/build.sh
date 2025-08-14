#!/usr/bin/env bash

run_action overlay

start_box

wait_for_ssh

# Install pre-requisites
run_in_box "sudo pacman -Sy --noconfirm wget base-devel"

# Install Omarchy, setting the terminal to `vt100` to keep `python-terminaltexteffects` happy.
run_in_box "export TERM=vt100; wget -qO- https://omarchy.org/install | bash"

BUILD_EC=$?

# Exit on non-zero exit code
if [[ ${BUILD_EC} -ne 0 ]]; then
  echo "Omarchy installation failed with exit code ${BUILD_EC}" >&2
  exit "${BUILD_EC}"
fi
