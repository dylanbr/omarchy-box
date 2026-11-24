#!/usr/bin/env bash

# Multi-instance lifecycle helpers: ports, pidfiles, stop/status, ephemeral disks.

OMARCHY_BOX_EPHEMERAL="${OMARCHY_BOX_EPHEMERAL:-false}"
OMARCHY_BOX_SSH_PORT_EXPLICIT="${OMARCHY_BOX_SSH_PORT_EXPLICIT:-false}"
OMARCHY_BOX_EPHEMERAL_DISK=""

instance_pidfile() {
  echo "${OMARCHY_BOX_INSTANCE_DIR}/.qemu.pid"
}

refresh_pidfile_path() {
  PIDFILE="$(instance_pidfile)"
}

instance_pid() {
  local pidfile
  pidfile="$(instance_pidfile)"
  if [[ -f "${pidfile}" ]]; then
    tr -d '[:space:]' < "${pidfile}"
  fi
}

instance_process_running() {
  local pid
  pid="$(instance_pid)"
  [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null
}

ssh_port_listening() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1 && return 0
  fi
  if command -v nc >/dev/null 2>&1; then
    nc -z 127.0.0.1 "${port}" >/dev/null 2>&1 && return 0
  fi
  return 1
}

claimed_ssh_ports() {
  local dir port pidfile
  shopt -s nullglob
  for dir in "${OMARCHY_BOX_DATA_DIR}/instances"/*; do
    [[ -d "${dir}" ]] || continue
    pidfile="${dir}/.qemu.pid"
    if [[ -f "${pidfile}" ]]; then
      local pid
      pid="$(tr -d '[:space:]' < "${pidfile}")"
      if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
        if [[ -f "${dir}/.ssh_port" ]]; then
          port="$(tr -d '[:space:]' < "${dir}/.ssh_port")"
          [[ -n "${port}" ]] && echo "${port}"
        fi
      fi
    fi
  done
  shopt -u nullglob
}

allocate_ssh_port() {
  local port="${OMARCHY_BOX_SSH_PORT:-2222}"
  local claimed

  if [[ "${OMARCHY_BOX_SSH_PORT_EXPLICIT}" == "true" ]]; then
    if ssh_port_listening "${port}"; then
      echo "SSH port ${port} is already in use." >&2
      return 1
    fi
    OMARCHY_BOX_SSH_PORT="${port}"
    return 0
  fi

  # Prefer a previously recorded port for this instance when free.
  if [[ -f "${OMARCHY_BOX_INSTANCE_DIR}/.ssh_port" ]]; then
    port="$(tr -d '[:space:]' < "${OMARCHY_BOX_INSTANCE_DIR}/.ssh_port")"
  fi

  while true; do
    claimed=false
    if ssh_port_listening "${port}"; then
      claimed=true
    else
      while read -r used; do
        if [[ "${used}" == "${port}" ]]; then
          claimed=true
          break
        fi
      done < <(claimed_ssh_ports)
    fi
    if [[ "${claimed}" != "true" ]]; then
      OMARCHY_BOX_SSH_PORT="${port}"
      return 0
    fi
    port=$((port + 1))
    if (( port > 65000 )); then
      echo "Could not find a free SSH port." >&2
      return 1
    fi
  done
}

write_instance_runtime_metadata() {
  mkdir -p "${OMARCHY_BOX_INSTANCE_DIR}"
  printf '%s\n' "${OMARCHY_BOX_SSH_PORT}" > "${OMARCHY_BOX_INSTANCE_DIR}/.ssh_port"
  printf '%s\n' "${OMARCHY_BOX_GUEST_ARCH}" > "${OMARCHY_BOX_INSTANCE_DIR}/.arch"
  printf '%s\n' "${OMARCHY_BOX_CPUS}" > "${OMARCHY_BOX_INSTANCE_DIR}/.cpus"
  printf '%s\n' "${OMARCHY_BOX_RAM}" > "${OMARCHY_BOX_INSTANCE_DIR}/.ram"
}

load_instance_ssh_port() {
  if [[ -f "${OMARCHY_BOX_INSTANCE_DIR}/.ssh_port" ]]; then
    OMARCHY_BOX_SSH_PORT="$(tr -d '[:space:]' < "${OMARCHY_BOX_INSTANCE_DIR}/.ssh_port")"
  fi
}

prepare_ephemeral_disk() {
  local base="$1"
  local ephemeral="${OMARCHY_BOX_INSTANCE_DIR}/ephemeral.qcow2"

  rm -f "${ephemeral}"
  qemu-img create -f qcow2 -F qcow2 -b "${base}" "${ephemeral}" >/dev/null
  OMARCHY_BOX_EPHEMERAL_DISK="${ephemeral}"
  echo "${ephemeral}"
}

cleanup_ephemeral_disk() {
  if [[ -n "${OMARCHY_BOX_EPHEMERAL_DISK}" && -f "${OMARCHY_BOX_EPHEMERAL_DISK}" ]]; then
    rm -f "${OMARCHY_BOX_EPHEMERAL_DISK}"
  fi
  OMARCHY_BOX_EPHEMERAL_DISK=""
}

stop_instance() {
  local pid pidfile
  refresh_pidfile_path
  pidfile="$(instance_pidfile)"
  pid="$(instance_pid)"

  if [[ -z "${pid}" ]]; then
    echo "Instance '${OMARCHY_BOX_INSTANCE}' is not running."
    return 0
  fi

  if ! kill -0 "${pid}" 2>/dev/null; then
    echo "Removing stale pidfile for instance '${OMARCHY_BOX_INSTANCE}'."
    rm -f "${pidfile}"
    return 0
  fi

  echo "Stopping instance '${OMARCHY_BOX_INSTANCE}' (PID ${pid})…"
  load_instance_ssh_port
  ensure_instance_ssh_key
  QEMU_PID="${pid}"

  if run_in_box "sudo systemctl poweroff" >/dev/null 2>&1; then
    echo "Sent poweroff to guest…"
    local _
    for _ in {1..30}; do
      if ! kill -0 "${pid}" 2>/dev/null; then
        rm -f "${pidfile}"
        cleanup_ephemeral_disk
        echo "Stopped."
        QEMU_PID=""
        return 0
      fi
      sleep 0.5
    done
  fi

  echo "Forcing QEMU stop…"
  kill -TERM "${pid}" 2>/dev/null || true
  sleep 1
  if kill -0 "${pid}" 2>/dev/null; then
    kill -KILL "${pid}" 2>/dev/null || true
  fi
  rm -f "${pidfile}"
  cleanup_ephemeral_disk
  QEMU_PID=""
  echo "Stopped."
}

print_instance_status() {
  local dir name version media arch port disk state pid
  dir="${1:-${OMARCHY_BOX_INSTANCE_DIR}}"
  name="$(basename "${dir}")"
  version="(not installed)"
  media="-"
  arch="-"
  port="-"
  disk="-"
  state="stopped"
  pid="-"

  [[ -f "${dir}/.ready" ]] && version="$(tr -d '[:space:]' < "${dir}/.ready")"
  [[ -f "${dir}/.media" ]] && media="$(tr -d '[:space:]' < "${dir}/.media")"
  [[ -f "${dir}/.arch" ]] && arch="$(tr -d '[:space:]' < "${dir}/.arch")"
  [[ -f "${dir}/.ssh_port" ]] && port="$(tr -d '[:space:]' < "${dir}/.ssh_port")"
  if [[ -f "${dir}/disk.qcow2" ]]; then
    disk="$(du -h "${dir}/disk.qcow2" 2>/dev/null | awk '{print $1}')"
  fi
  if [[ -f "${dir}/.qemu.pid" ]]; then
    pid="$(tr -d '[:space:]' < "${dir}/.qemu.pid")"
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      state="running"
    else
      state="stale-pid"
      pid="${pid}"
    fi
  fi

  printf 'instance: %s\n' "${name}"
  printf '  state:    %s\n' "${state}"
  printf '  version:  %s\n' "${version}"
  printf '  media:    %s\n' "${media}"
  printf '  arch:     %s\n' "${arch}"
  printf '  ssh_port: %s\n' "${port}"
  printf '  disk:     %s\n' "${disk}"
  printf '  pid:      %s\n' "${pid}"
  if [[ -f "${dir}/id_ed25519" && "${port}" != "-" ]]; then
    printf '  ssh:      ssh -i %s -p %s %s@%s\n' \
      "${dir}/id_ed25519" "${port}" "${OMARCHY_BOX_SSH_USER}" "${OMARCHY_BOX_SSH_HOST}"
  fi
}
