#!/usr/bin/env bash

QEMU_PID=""
PIDFILE=".qemu.pid"

QEMU_CMD=(
  qemu-system-x86_64
  -smp ${OMARCHY_BOX_CPUS}
  -m ${OMARCHY_BOX_RAM}
  -drive "if=virtio,file=${OMARCHY_BOX_OVERLAY_IMAGE},format=qcow2,cache=none"
  -nic user,model=virtio-net-pci,hostfwd=tcp::${OMARCHY_BOX_SSH_PORT}-:22
  # Provide a random number generator to the VM, so it can generate SSH keys and other things that need randomness. This is important
  # for the first boot, as the VM will not have any entropy available
  -object rng-random,filename=/dev/urandom,id=rng0
  -device virtio-rng-pci,rng=rng0
  #-nographic
  # uncomment if you want a throwaway VM session (no writes persisted):
  # -snapshot
)

# Decide which virtualization or emulation to use based on the operating system and host architecture. We are always wanting to run
# the box on `amd64`, so virtualize on AMD/Intel and emulate on ARM.
case "$(uname -s)" in
  Linux)
    case "$(uname -m)" in
      x86_64|amd64)
        # Intel/AMD Linux
        QEMU_CMD+=(-accel kvm -cpu host)
        ;;
      aarch64|arm64)
        # ARM Linux
        QEMU_CMD+=(-accel tcg,thread=multi -cpu max)
        ;;
      *)
        echo "Unsupported architecture: $(uname -m) on Linux"
        exit 1
        ;;
    esac
    ;;
  Darwin)
    case "$(uname -m)" in
      x86_64)
        # Intel mac
        QEMU_CMD+=(-accel hvf -cpu host)
        ;;
      arm64|aarch64)
        # Apple silicon mac
        QEMU_CMD+=(-accel tcg,thread=multi -cpu max)
        ;;
      *)
        echo "Unsupported architecture: ${host_arch} on macOS"
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Unsupported operating system: ${os}"
    exit 1
    ;;
esac

start_box() {
  echo "Starting Omarchy box…"
  "${QEMU_CMD[@]}" &
  QEMU_PID=$!
  echo "${QEMU_PID}" > "${PIDFILE}"

  trap 'shutdown_box $?' EXIT INT TERM

  disown "${QEMU_PID}" || true
}

box_running() {
  echo "Checking PID ${QEMU_PID}"
  [[ -n "${QEMU_PID}" ]] && kill -0 "${QEMU_PID}" 2>/dev/null
}

shutdown_box_soft() {
  echo "Attempting graceful shutdown…"
  # Try ACPI powerdown via guest OS
  if "${ssh_cmd[@]}" "sudo systemctl poweroff" >/dev/null 2>&1; then
    echo "Sent poweroff command to guest OS, waiting for shutdown…"
  fi

  # Wait a few seconds for process to exit
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
    echo "Failed to stop QEMU (PID ${QEMU_PID}), exiting with error."
    echo "You may need to manually stop the QEMU process."
    return 1
  fi
}

shutdown_box() {
  # Don’t accidentally override the build’s exit status
  local ec="${1:-$?}"

  # Try soft stop, then hard
  shutdown_box_soft || shutdown_box_hard
  rm -f "${PIDFILE}"

  exit "${ec}"
}
