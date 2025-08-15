#!/usr/bin/env bash

cat <<EOF
Usage: $0 <command> [options]

Primary Commands:
  build      Build the Omarchy image by running the installer
  start      Start the last built Omarchy image

Other Commands:
  download   Download and verify the base Arch Linux image
  clean      Erase all data and start fresh
  help       Show this message

EOF

exit 1
