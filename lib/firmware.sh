#!/usr/bin/env bash

# Locate UEFI firmware (code + vars) for the selected guest arch.
# Callers must source lib/arch.sh first.

OMARCHY_BOX_FIRMWARE_CODE=""
OMARCHY_BOX_FIRMWARE_VARS=""

_firmware_candidates_x86_64() {
  cat <<'EOF'
/opt/homebrew/share/qemu/edk2-x86_64-code.fd
/usr/local/share/qemu/edk2-x86_64-code.fd
/usr/share/OVMF/OVMF_CODE_4M.fd
/usr/share/OVMF/OVMF_CODE.fd
/usr/share/edk2/x64/OVMF_CODE.4m.fd
/usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd
/usr/share/edk2-ovmf/OVMF_CODE.fd
/usr/share/qemu/edk2-x86_64-code.fd
EOF
}

_firmware_vars_candidates_x86_64() {
  cat <<'EOF'
/opt/homebrew/share/qemu/edk2-x86_64-vars.fd
/usr/local/share/qemu/edk2-x86_64-vars.fd
/usr/share/OVMF/OVMF_VARS_4M.fd
/usr/share/OVMF/OVMF_VARS.fd
/usr/share/edk2/x64/OVMF_VARS.4m.fd
/usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd
/usr/share/edk2-ovmf/OVMF_VARS.fd
/usr/share/qemu/edk2-x86_64-vars.fd
EOF
}

_firmware_candidates_aarch64() {
  cat <<'EOF'
/opt/homebrew/share/qemu/edk2-aarch64-code.fd
/usr/local/share/qemu/edk2-aarch64-code.fd
/usr/share/AAVMF/AAVMF_CODE.fd
/usr/share/edk2/aarch64/QEMU_EFI-pflash.raw
/usr/share/qemu/edk2-aarch64-code.fd
EOF
}

_firmware_vars_candidates_aarch64() {
  cat <<'EOF'
/opt/homebrew/share/qemu/edk2-arm-vars.fd
/usr/local/share/qemu/edk2-arm-vars.fd
/usr/share/AAVMF/AAVMF_VARS.fd
/usr/share/edk2/aarch64/vars-template-pflash.raw
/usr/share/qemu/edk2-arm-vars.fd
EOF
}

_find_first_existing() {
  local path
  while IFS= read -r path; do
    if [[ -n "${path}" && -f "${path}" ]]; then
      echo "${path}"
      return 0
    fi
  done
  return 1
}

resolve_firmware() {
  local code_list vars_list

  if [[ -n "${OMARCHY_BOX_FIRMWARE_CODE_OVERRIDE:-}" ]]; then
    OMARCHY_BOX_FIRMWARE_CODE="${OMARCHY_BOX_FIRMWARE_CODE_OVERRIDE}"
  else
    if [[ "${OMARCHY_BOX_GUEST_ARCH}" == "x86_64" ]]; then
      code_list="$(_firmware_candidates_x86_64)"
    else
      code_list="$(_firmware_candidates_aarch64)"
    fi
    OMARCHY_BOX_FIRMWARE_CODE="$(printf '%s\n' "${code_list}" | _find_first_existing)" || true
  fi

  if [[ -n "${OMARCHY_BOX_FIRMWARE_VARS_OVERRIDE:-}" ]]; then
    OMARCHY_BOX_FIRMWARE_VARS_TEMPLATE="${OMARCHY_BOX_FIRMWARE_VARS_OVERRIDE}"
  else
    if [[ "${OMARCHY_BOX_GUEST_ARCH}" == "x86_64" ]]; then
      vars_list="$(_firmware_vars_candidates_x86_64)"
    else
      vars_list="$(_firmware_vars_candidates_aarch64)"
    fi
    OMARCHY_BOX_FIRMWARE_VARS_TEMPLATE="$(printf '%s\n' "${vars_list}" | _find_first_existing)" || true
  fi

  if [[ -z "${OMARCHY_BOX_FIRMWARE_CODE}" ]]; then
    echo "Could not find UEFI firmware for ${OMARCHY_BOX_GUEST_ARCH}." >&2
    echo "Install QEMU firmware (e.g. brew: qemu, apt: ovmf / qemu-efi-aarch64)," >&2
    echo "or set OMARCHY_BOX_FIRMWARE_CODE_OVERRIDE / OMARCHY_BOX_FIRMWARE_VARS_OVERRIDE." >&2
    return 1
  fi

  if [[ -z "${OMARCHY_BOX_FIRMWARE_VARS_TEMPLATE:-}" ]]; then
    echo "Could not find UEFI vars template for ${OMARCHY_BOX_GUEST_ARCH}." >&2
    echo "Set OMARCHY_BOX_FIRMWARE_VARS_OVERRIDE to a writable vars template." >&2
    return 1
  fi
}

# Copy the vars template into the instance dir so Secure Boot / NVRAM state is per-VM.
prepare_firmware_vars() {
  local dest="${1}"
  resolve_firmware
  mkdir -p "$(dirname "${dest}")"
  if [[ ! -f "${dest}" ]]; then
    cp "${OMARCHY_BOX_FIRMWARE_VARS_TEMPLATE}" "${dest}"
  fi
  OMARCHY_BOX_FIRMWARE_VARS="${dest}"
}
