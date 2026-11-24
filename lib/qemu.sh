#!/usr/bin/env bash

# QEMU lifecycle for Omarchy Box.
# Requires: lib/arch.sh, lib/firmware.sh, lib/ssh.sh

QEMU_PID=""
PIDFILE="${OMARCHY_BOX_INSTANCE_DIR:-.}/.qemu.pid"

_append_accel() {
  local -n _cmd=$1

  if [[ "${OMARCHY_BOX_NATIVE_VIRT}" != "true" ]]; then
    _cmd+=(-accel tcg,thread=multi)
    return
  fi

  case "${OMARCHY_BOX_HOST_OS}" in
    Linux)
      if [[ -r /dev/kvm && -w /dev/kvm ]]; then
        _cmd+=(-accel kvm)
      else
        echo "WARNING: /dev/kvm not usable; falling back to TCG." >&2
        _cmd+=(-accel tcg,thread=multi)
      fi
      ;;
    Darwin)
      _cmd+=(-accel hvf)
      ;;
  esac
}

build_qemu_cmd() {
  local disk="$1"
  local firmware_vars="$2"
  local iso="${3:-}"
  local cidata="${4:-}"
  local cidata_format="${5:-raw}"
  local smbios_b64="${6:-}"

  resolve_firmware
  prepare_firmware_vars "${firmware_vars}"

  local -a cmd=("${OMARCHY_BOX_QEMU_BIN}")

  if [[ "${OMARCHY_BOX_GUEST_ARCH}" == "x86_64" ]]; then
    cmd+=(-machine q35)
  else
    cmd+=(-machine virt,gic-version=max)
  fi

  _append_accel cmd

  if [[ "${OMARCHY_BOX_NATIVE_VIRT}" == "true" ]]; then
    cmd+=(-cpu host)
  else
    cmd+=(-cpu max)
  fi

  cmd+=(
    -smp "${OMARCHY_BOX_CPUS}"
    -m "${OMARCHY_BOX_RAM}"
    -drive "if=pflash,format=raw,readonly=on,file=${OMARCHY_BOX_FIRMWARE_CODE}"
    -drive "if=pflash,format=raw,file=${OMARCHY_BOX_FIRMWARE_VARS}"
    -drive "if=none,file=${disk},format=qcow2,cache=none,discard=unmap,id=disk0"
    -device virtio-blk-pci,drive=disk0,bootindex=1
    -netdev "user,id=n0,hostfwd=tcp::${OMARCHY_BOX_SSH_PORT}-:22"
    -device virtio-net-pci,netdev=n0
    -object rng-random,filename=/dev/urandom,id=rng0
    -device virtio-rng-pci,rng=rng0
    -device virtio-vga
    -device qemu-xhci
    -device usb-tablet
    -device usb-kbd
  )

  if [[ -n "${iso}" ]]; then
    cmd+=(
      -device virtio-scsi-pci,id=scsi0
      -drive "if=none,file=${iso},format=raw,media=cdrom,readonly=on,id=cd0"
      -device scsi-cd,drive=cd0,bootindex=2
    )
  fi

  if [[ -n "${cidata}" ]]; then
    if [[ "${cidata_format}" == "iso" ]]; then
      cmd+=(
        -drive "if=none,file=${cidata},format=raw,media=cdrom,readonly=on,id=cidata"
        -device scsi-cd,drive=cidata
      )
    else
      cmd+=(
        -drive "if=none,file=${cidata},format=raw,id=cidata"
        -device usb-storage,drive=cidata
      )
    fi
  fi

  if [[ -n "${smbios_b64}" ]]; then
    cmd+=(-smbios "type=11,value=io.systemd.credential.binary:tmpfiles.extra=${smbios_b64}")
  fi

  if [[ "${OMARCHY_BOX_DISPLAY:-gui}" == "none" ]]; then
    cmd+=(-display none -serial mon:stdio)
  fi

  printf '%s\0' "${cmd[@]}"
}

start_box() {
  local disk="${1:-${OMARCHY_BOX_IMAGE}}"
  local firmware_vars="${2:-${OMARCHY_BOX_INSTANCE_DIR:-.}/efivars.fd}"
  local iso="${3:-}"
  local cidata="${4:-}"
  local cidata_format="${5:-raw}"
  local smbios_b64="${6:-}"

  if [[ -z "${disk}" || ! -f "${disk}" ]]; then
    echo "Disk image not found: ${disk:-"(unset)"}" >&2
    return 1
  fi

  echo "Starting Omarchy box (${OMARCHY_BOX_GUEST_ARCH}, ${OMARCHY_BOX_CPUS} CPUs, ${OMARCHY_BOX_RAM} MB)…"

  local -a cmd=()
  while IFS= read -r -d '' arg; do
    cmd+=("${arg}")
  done < <(build_qemu_cmd "${disk}" "${firmware_vars}" "${iso}" "${cidata}" "${cidata_format}" "${smbios_b64}")

  "${cmd[@]}" &
  QEMU_PID=$!
  echo "${QEMU_PID}" > "${PIDFILE}"

  trap 'shutdown_box $?' EXIT INT TERM
}

box_running() {
  [[ -n "${QEMU_PID}" ]] && kill -0 "${QEMU_PID}" 2>/dev/null
}

shutdown_box_soft() {
  echo "Attempting graceful shutdown…"
  if run_in_box "sudo systemctl poweroff" >/dev/null 2>&1; then
    echo "Sent poweroff command to guest OS, waiting for shutdown…"
  fi

  local _
  for _ in {1..20}; do
    if ! box_running; then
      echo "Graceful shutdown succeeded."
      return 0
    fi
    sleep 0.5
  done

  echo "Graceful shutdown did not complete in time."
  return 1
}

shutdown_box_hard() {
  if box_running; then
    echo "Sending TERM signal to QEMU (PID ${QEMU_PID})…"
    kill -TERM "${QEMU_PID}" 2>/dev/null || true
    sleep 1
    if box_running; then
      echo "TERM signal did not work, sending KILL signal…"
      kill -KILL "${QEMU_PID}" 2>/dev/null || true
    fi
  fi

  if box_running; then
    echo "Failed to stop QEMU (PID ${QEMU_PID})." >&2
    return 1
  fi
}

shutdown_box() {
  local ec="${1:-$?}"
  shutdown_box_soft || shutdown_box_hard
  rm -f "${PIDFILE}"
  exit "${ec}"
}
