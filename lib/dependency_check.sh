#!/usr/bin/env bash

required_commands=(
  qemu-system-x86_64
  sshpass
)

missing_commands=()
for cmd in "${required_commands[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing_commands+=("$cmd")
  fi
done

if [[ ${#missing_commands[@]} -ne 0 ]]; then
  echo "The following required commands are missing: ${missing_commands[*]}"
  echo
  echo "Please install the missing commands and try again."
  exit 1
fi
