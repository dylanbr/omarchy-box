#!/usr/bin/env bash

# QEMU lifecycle for Omarchy Box.
# Requires: lib/arch.sh, lib/firmware.sh, lib/ssh.sh

QEMU_PID=""
PIDFILE="${OMARCHY_BOX_INSTANCE_DIR:-.}/.qemu.pid"

# Sets QEMU_ACCEL_ARGS for the current host (bash 3.2 compatible; no namerefs).
_set_accel_args() {
  QEMU_ACCEL_ARGS=()

  if [[ "${OMARCHY_BOX_NATIVE_VIRT}" != "true" ]]; then
    QEMU_ACCEL_ARGS+=(-accel tcg,thread=multi)
    return
  fi

  case "${OMARCHY_BOX_HOST_OS}" in
    Linux)
      if [[ -r /dev/kvm && -w /dev/kvm ]]; then
        QEMU_ACCEL_ARGS+=(-accel kvm)
      else
        echo "WARNING: /dev/kvm not usable; falling back to TCG." >&2
        QEMU_ACCEL_ARGS+=(-accel tcg,thread=multi)
      fi
      ;;
    Darwin)
      QEMU_ACCEL_ARGS+=(-accel hvf)
      ;;
  esac
}

# True if the current QEMU binary lists a display backend name.
_qemu_has_display() {
  local name="$1"
  "${OMARCHY_BOX_QEMU_BIN}" -display help 2>&1 | grep -qx "${name}"
}

# Sets QEMU_DISPLAY_ARGS for GUI mode.
# macOS (Intel + Apple Silicon): Cocoa with zoom-to-fit so the window is
# resizable and guest splash/desktop scales into it (helps Retina HiDPI).
# Linux (x86_64 + aarch64): GTK zoom-to-fit when available; else SDL; else
# leave QEMU's default. Guest GPU stays arch-specific (virtio-vga / virtio-gpu).
_set_gui_display_args() {
  QEMU_DISPLAY_ARGS=()
  local zoom="${OMARCHY_BOX_ZOOM_TO_FIT:-on}"
  local zoom_opt=""

  case "${zoom}" in
    on|true|1|yes) zoom_opt=",zoom-to-fit=on" ;;
    off|false|0|no) zoom_opt="" ;;
    *)
      echo "WARNING: ignoring invalid OMARCHY_BOX_ZOOM_TO_FIT=${zoom} (use on|off)." >&2
      zoom_opt=",zoom-to-fit=on"
      ;;
  esac

  case "${OMARCHY_BOX_HOST_OS}" in
    Darwin)
      QEMU_DISPLAY_ARGS+=(-display "cocoa${zoom_opt}")
      ;;
    Linux)
      if _qemu_has_display gtk; then
        QEMU_DISPLAY_ARGS+=(-display "gtk${zoom_opt}")
      elif _qemu_has_display sdl; then
        # SDL has no zoom-to-fit; window still opens for local desktop use.
        QEMU_DISPLAY_ARGS+=(-display sdl)
      fi
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

  _set_accel_args
  if [[ ${#QEMU_ACCEL_ARGS[@]} -gt 0 ]]; then
    cmd+=("${QEMU_ACCEL_ARGS[@]}")
  fi

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
    -device qemu-xhci
    -device usb-tablet
    -device usb-kbd
  )

  # virtio-vga is x86-only; aarch64 QEMU exposes virtio-gpu-pci instead.
  if [[ "${OMARCHY_BOX_GUEST_ARCH}" == "x86_64" ]]; then
    cmd+=(-device virtio-vga)
  else
    cmd+=(-device virtio-gpu-pci)
  fi

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

  case "${OMARCHY_BOX_DISPLAY:-gui}" in
    none)
      cmd+=(-display none -serial mon:stdio)
      ;;
    gui)
      _set_gui_display_args
      if [[ ${#QEMU_DISPLAY_ARGS[@]} -gt 0 ]]; then
        cmd+=("${QEMU_DISPLAY_ARGS[@]}")
      fi
      ;;
    *)
      # Allow a raw QEMU -display value, e.g. vnc=:1 or cocoa,full-screen=on.
      cmd+=(-display "${OMARCHY_BOX_DISPLAY}")
      ;;
  esac

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

  PIDFILE="${OMARCHY_BOX_INSTANCE_DIR:-.}/.qemu.pid"

  echo "Starting Omarchy box (${OMARCHY_BOX_GUEST_ARCH}, ${OMARCHY_BOX_CPUS} CPUs, ${OMARCHY_BOX_RAM} MB, ssh :${OMARCHY_BOX_SSH_PORT})…"

  local -a cmd=()
  while IFS= read -r -d '' arg; do
    cmd+=("${arg}")
  done < <(build_qemu_cmd "${disk}" "${firmware_vars}" "${iso}" "${cidata}" "${cidata_format}" "${smbios_b64}")

  "${cmd[@]}" &
  QEMU_PID=$!
  echo "${QEMU_PID}" > "${PIDFILE}"
  if declare -F write_instance_runtime_metadata >/dev/null; then
    write_instance_runtime_metadata
  fi

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
  if declare -F cleanup_ephemeral_disk >/dev/null; then
    cleanup_ephemeral_disk
  fi
  exit "${ec}"
}
