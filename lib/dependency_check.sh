#!/usr/bin/env bash

# Requires lib/arch.sh to be sourced first (sets OMARCHY_BOX_QEMU_BIN).
# Call ensure_runtime_dependencies from actions that need QEMU/SSH.

if ! command -v sha256sum >/dev/null 2>&1 && command -v shasum >/dev/null 2>&1; then
  sha256sum() {
    shasum -a 256 "$@"
  }
fi

_print_qemu_install_hints() {
  case "${OMARCHY_BOX_HOST_OS}" in
    Darwin)
      echo "On macOS with Homebrew: brew install qemu"
      ;;
    Linux)
      echo "On Arch / Omarchy: sudo pacman -S qemu-desktop"
      echo "On Debian/Ubuntu: sudo apt install qemu-system-x86 qemu-system-arm qemu-system-gui qemu-utils ovmf qemu-efi-aarch64"
      echo "On Fedora: sudo dnf install qemu-system-x86 qemu-system-aarch64 edk2-ovmf edk2-aarch64"
      ;;
  esac
}

# True if QEMU lists a device model name (exact match on the quoted name).
_qemu_has_device() {
  local name="$1"
  "${OMARCHY_BOX_QEMU_BIN}" -device help 2>&1 | grep -Eq "name \"${name}\""
}

# Arch (and similar) split QEMU into modules. virtio-vga.so can load and
# register the device even when virtio-gpu is missing; creating the device
# then SIGSEGVs. Detect that incomplete install before we launch.
_qemu_virtio_gpu_modules_ok() {
  local qemu_lib=""
  local dir
  for dir in /usr/lib/qemu /usr/libexec/qemu /usr/local/lib/qemu; do
    if [[ -d "${dir}" ]]; then
      qemu_lib="${dir}"
      break
    fi
  done

  # Non-modular builds (Homebrew, etc.) ship devices in the binary — nothing to check.
  [[ -z "${qemu_lib}" ]] && return 0

  case "${OMARCHY_BOX_GUEST_ARCH}" in
    x86_64)
      # virtio-vga wraps virtio-gpu; both modules must be present together.
      if [[ -f "${qemu_lib}/hw-display-virtio-vga.so" && ! -f "${qemu_lib}/hw-display-virtio-gpu.so" ]]; then
        return 1
      fi
      ;;
    aarch64)
      if [[ ! -f "${qemu_lib}/hw-display-virtio-gpu-pci.so" && ! -f "${qemu_lib}/hw-display-virtio-gpu.so" ]]; then
        # Only fail when modules are used at all (vga present implies modular).
        if [[ -f "${qemu_lib}/hw-display-virtio-vga.so" ]]; then
          return 1
        fi
      fi
      ;;
  esac
  return 0
}

_ensure_qemu_display_device() {
  local want=""

  case "${OMARCHY_BOX_GUEST_ARCH}" in
    x86_64) want="virtio-vga" ;;
    aarch64) want="virtio-gpu-pci" ;;
  esac

  if ! _qemu_has_device "${want}"; then
    echo "QEMU is missing the '${want}' display device required for Omarchy Box." >&2
    echo
    _print_qemu_install_hints
    exit 1
  fi

  if ! _qemu_virtio_gpu_modules_ok; then
    echo "QEMU's virtio GPU modules are incomplete (virtio-vga without virtio-gpu)." >&2
    echo "This commonly happens with Arch's qemu-base package and causes a QEMU crash." >&2
    echo
    _print_qemu_install_hints
    exit 1
  fi
}

_ensure_qemu_gui_backend() {
  # Headless / raw -display values are the caller's responsibility.
  [[ "${OMARCHY_BOX_DISPLAY:-gui}" != "gui" ]] && return 0

  case "${OMARCHY_BOX_HOST_OS}" in
    Darwin)
      return 0
      ;;
    Linux)
      if "${OMARCHY_BOX_QEMU_BIN}" -display help 2>&1 | grep -Eqx 'gtk|sdl'; then
        return 0
      fi
      echo "QEMU has no GUI display backend (need gtk or sdl)." >&2
      echo "You only have a headless QEMU install; the VM window cannot open." >&2
      echo
      _print_qemu_install_hints
      exit 1
      ;;
  esac
}

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
    _print_qemu_install_hints
    exit 1
  fi

  _ensure_qemu_display_device
  _ensure_qemu_gui_backend

  if [[ -n "${OMARCHY_BOX_SSH_PASS:-}" ]] && ! command -v sshpass >/dev/null 2>&1; then
    if [[ "${OMARCHY_BOX_SSHPASS_WARNED:-}" != "true" ]]; then
      echo "Note: sshpass is not installed; password SSH fallback is unavailable." >&2
      echo "Key-based auth (OMARCHY_BOX_SSH_KEY) is preferred." >&2
      OMARCHY_BOX_SSHPASS_WARNED=true
    fi
  fi
}
