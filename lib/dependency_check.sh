#!/usr/bin/env bash

# Requires lib/arch.sh to be sourced first (sets OMARCHY_BOX_QEMU_BIN).
# Call ensure_runtime_dependencies from actions that need QEMU/SSH.

if ! command -v sha256sum >/dev/null 2>&1 && command -v shasum >/dev/null 2>&1; then
  sha256sum() {
    shasum -a 256 "$@"
  }
fi

ensure_runtime_dependencies() {
  local required_commands=(
    "${OMARCHY_BOX_QEMU_BIN}"
    qemu-img
    ssh
    scp
    curl
  )
  local missing_commands=()
  local cmd

  for cmd in "${required_commands[@]}"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      missing_commands+=("${cmd}")
    fi
  done

  if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    missing_commands+=("sha256sum|shasum")
  fi

  if [[ ${#missing_commands[@]} -ne 0 ]]; then
    echo "The following required commands are missing: ${missing_commands[*]}"
    echo
    case "${OMARCHY_BOX_HOST_OS}" in
      Darwin)
        echo "On macOS with Homebrew: brew install qemu"
        ;;
      Linux)
        echo "On Debian/Ubuntu: sudo apt install qemu-system-x86 qemu-system-arm qemu-utils ovmf qemu-efi-aarch64"
        echo "On Fedora: sudo dnf install qemu-system-x86 qemu-system-aarch64 edk2-ovmf edk2-aarch64"
        ;;
    esac
    exit 1
  fi

  if [[ -n "${OMARCHY_BOX_SSH_PASS:-}" ]] && ! command -v sshpass >/dev/null 2>&1; then
    if [[ "${OMARCHY_BOX_SSHPASS_WARNED:-}" != "true" ]]; then
      echo "Note: sshpass is not installed; password SSH fallback is unavailable." >&2
      echo "Key-based auth (OMARCHY_BOX_SSH_KEY) is preferred." >&2
      OMARCHY_BOX_SSHPASS_WARNED=true
    fi
  fi
}
