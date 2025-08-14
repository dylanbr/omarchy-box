#!/usr/bin/env bash

cat <<EOF
Usage: $0 <command> [options]

Commands:
  clean      Clear all data
  download   Download and verify the base Arch Linux image
  help       Show this message

Options:
  -n, --name NAME     Name or identifier
  -h, --help          Show this help message

Examples:
  $0 clean
  $0 download
EOF

exit 1
