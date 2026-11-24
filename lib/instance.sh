#!/usr/bin/env bash

# Prepare and boot an Omarchy Box instance from official media.

OMARCHY_BOX_INSTALL_TIMEOUT_SECS="${OMARCHY_BOX_INSTALL_TIMEOUT_SECS:-2400}"

instance_ready() {
  [[ -f "${OMARCHY_BOX_IMAGE}" && -f "${OMARCHY_BOX_INSTANCE_DIR}/.ready" ]]
}

installed_version() {
  if [[ -f "${OMARCHY_BOX_INSTANCE_DIR}/.ready" ]]; then
    tr -d '[:space:]' < "${OMARCHY_BOX_INSTANCE_DIR}/.ready"
  fi
}

mark_instance_ready() {
  printf '%s\n' "${OMARCHY_BOX_RESOLVED_VERSION:-unknown}" > "${OMARCHY_BOX_INSTANCE_DIR}/.ready"
  printf '%s\n' "${OMARCHY_BOX_MEDIA_KIND:-unknown}" > "${OMARCHY_BOX_INSTANCE_DIR}/.media"
  printf '%s\n' "${OMARCHY_BOX_GUEST_ARCH}" > "${OMARCHY_BOX_INSTANCE_DIR}/.arch"
}

prepare_qcow_instance() {
  OMARCHY_BOX_BASE_IMAGE="${OMARCHY_BOX_BASE_IMAGE}"
  source "${OMARCHY_BOX_BASE_DIR}/actions/overlay.sh"
  mark_instance_ready
}

prepare_iso_instance() {
  local disk="${OMARCHY_BOX_IMAGE}"
  local vars="${OMARCHY_BOX_INSTANCE_DIR}/efivars.fd"
  local cidata="${OMARCHY_BOX_INSTANCE_DIR}/cidata.img"
  local smbios=""

  echo "Creating blank install disk (${OMARCHY_BOX_DISK_GB:-40}G)…"
  rm -f "${disk}"
  qemu-img create -f qcow2 "${disk}" "${OMARCHY_BOX_DISK_GB:-40}G" >/dev/null

  rm -f "${vars}"
  resolve_firmware
  prepare_firmware_vars "${vars}"

  ensure_instance_ssh_key
  allocate_ssh_port
  echo "Building unattended install (cidata) image…"
  build_cidata_image "${cidata}" "${OMARCHY_BOX_SSH_PUBKEY}"
  cidata="${OMARCHY_BOX_CIDATA_IMAGE}"

  echo "Starting unattended ISO install (this can take a long time)…"
  echo "The guest user is ${OMARCHY_BOX_SSH_USER}; SSH will answer when install finishes."
  start_box "${disk}" "${vars}" "${OMARCHY_BOX_ISO}" "${cidata}" "${OMARCHY_BOX_CIDATA_FORMAT}" "${smbios}"

  local previous_timeout="${OMARCHY_BOX_SSH_TIMEOUT_SECS}"
  OMARCHY_BOX_SSH_TIMEOUT_SECS="${OMARCHY_BOX_INSTALL_TIMEOUT_SECS}"
  wait_for_ssh
  OMARCHY_BOX_SSH_TIMEOUT_SECS="${previous_timeout}"

  echo "Install finished. Shutting down to detach install media…"
  shutdown_box_soft || shutdown_box_hard
  trap - EXIT INT TERM
  QEMU_PID=""
  rm -f "${PIDFILE}"

  mark_instance_ready
  echo "Install complete."
}

prepare_instance() {
  ensure_runtime_dependencies
  ensure_instance_ssh_key
  download_resolved_media

  if [[ "${OMARCHY_BOX_MEDIA_KIND}" == "qcow" ]]; then
    prepare_qcow_instance
  else
    prepare_iso_instance
  fi
}

# Decide whether the existing instance can be reused for the requested version.
ensure_instance_matches_request() {
  local requested installed
  requested="$(normalize_omarchy_version "${OMARCHY_BOX_VERSION:-latest}")"
  installed="$(installed_version)"

  [[ -n "${installed}" ]] || return 0

  if [[ "${OMARCHY_BOX_FORCE}" == "true" ]]; then
    echo "Forcing recreate of instance '${OMARCHY_BOX_INSTANCE}' (was ${installed})."
    rm -f "${OMARCHY_BOX_IMAGE}" "${OMARCHY_BOX_INSTANCE_DIR}/.ready" "${OMARCHY_BOX_INSTANCE_DIR}/.media"
    return 0
  fi

  if [[ "${requested}" != "latest" && "${requested}" != "${installed}" ]]; then
    echo "Instance '${OMARCHY_BOX_INSTANCE}' has Omarchy ${installed}, but ${requested} was requested." >&2
    echo "Run: $0 clean --instance ${OMARCHY_BOX_INSTANCE}" >&2
    echo "Or pass --force to recreate it." >&2
    return 1
  fi
}

boot_instance() {
  local vars="${OMARCHY_BOX_INSTANCE_DIR}/efivars.fd"
  local smbios=""
  local disk="${OMARCHY_BOX_IMAGE}"

  ensure_runtime_dependencies
  ensure_instance_ssh_key
  ensure_instance_matches_request
  refresh_pidfile_path

  if instance_process_running; then
    echo "Instance '${OMARCHY_BOX_INSTANCE}' is already running (PID $(instance_pid))." >&2
    print_instance_status
    return 1
  fi

  if [[ ! -f "${OMARCHY_BOX_IMAGE}" ]]; then
    prepare_instance
  elif [[ ! -f "${OMARCHY_BOX_INSTANCE_DIR}/.ready" ]]; then
    echo "Found a disk without a completed install marker; recreating instance…"
    prepare_instance
  fi

  allocate_ssh_port

  if [[ "${OMARCHY_BOX_EPHEMERAL}" == "true" ]]; then
    echo "Ephemeral mode: changes will be discarded on stop."
    disk="$(prepare_ephemeral_disk "${OMARCHY_BOX_IMAGE}")"
  fi

  if [[ -f "${OMARCHY_BOX_INSTANCE_DIR}/.media" ]] && [[ "$(tr -d '[:space:]' < "${OMARCHY_BOX_INSTANCE_DIR}/.media")" == "qcow" ]]; then
    smbios="$(omarchy_box_smbios_ssh_credential "${OMARCHY_BOX_SSH_PUBKEY}")"
  fi

  start_box "${disk}" "${vars}" "" "" "raw" "${smbios}"

  echo "Instance: ${OMARCHY_BOX_INSTANCE}"
  echo "Desktop login: ${OMARCHY_BOX_SSH_USER} / ${OMARCHY_BOX_SSH_PASS}"
  echo "SSH: ssh -i ${OMARCHY_BOX_SSH_KEY} -p ${OMARCHY_BOX_SSH_PORT} ${OMARCHY_BOX_SSH_USER}@${OMARCHY_BOX_SSH_HOST}"
  if [[ -f "${OMARCHY_BOX_INSTANCE_DIR}/.ready" ]]; then
    echo "Installed version: $(installed_version)"
  fi
  if [[ "${OMARCHY_BOX_EPHEMERAL}" == "true" ]]; then
    echo "Mode: ephemeral"
  fi

  if wait_for_ssh; then
    echo "SSH is ready."
  else
    echo "SSH did not become ready in time; the desktop may still be usable." >&2
  fi
}
