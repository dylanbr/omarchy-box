#!/usr/bin/env bash

# SSH helpers for Omarchy Box.
# Prefer key-based auth. Password auth via sshpass is optional fallback only.

ensure_instance_ssh_key() {
  OMARCHY_BOX_SSH_KEY="${OMARCHY_BOX_SSH_KEY:-${OMARCHY_BOX_INSTANCE_DIR}/id_ed25519}"
  if [[ ! -f "${OMARCHY_BOX_SSH_KEY}" ]]; then
    mkdir -p "$(dirname "${OMARCHY_BOX_SSH_KEY}")"
    ssh-keygen -q -t ed25519 -N '' -C "omarchy-box-${OMARCHY_BOX_INSTANCE}" -f "${OMARCHY_BOX_SSH_KEY}"
  fi
  OMARCHY_BOX_SSH_PUBKEY="${OMARCHY_BOX_SSH_KEY}.pub"
}

# Build the base64 systemd tmpfiles credential used by sealed Omarchy qcow images.
omarchy_box_smbios_ssh_credential() {
  local pubkey="$1"
  local tmpfiles b64
  tmpfiles="$(printf 'd /home/%s/.ssh 0700 %s %s -\nf+ /home/%s/.ssh/authorized_keys 0600 %s %s - %s\n' \
    "${OMARCHY_BOX_SSH_USER}" "${OMARCHY_BOX_SSH_USER}" "${OMARCHY_BOX_SSH_USER}" \
    "${OMARCHY_BOX_SSH_USER}" "${OMARCHY_BOX_SSH_USER}" "${OMARCHY_BOX_SSH_USER}" \
    "$(tr -d '\n' < "${pubkey}")")"
  if base64 -w0 </dev/null >/dev/null 2>&1; then
    b64="$(printf '%s' "${tmpfiles}" | base64 -w0)"
  else
    b64="$(printf '%s' "${tmpfiles}" | base64 | tr -d '\n')"
  fi
  printf '%s' "${b64}"
}

_ssh_base_opts() {
  printf '%s\0' \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o GlobalKnownHostsFile=/dev/null \
    -o ConnectTimeout=3
}

_build_ssh_cmd() {
  local -a cmd=()
  local -a base=()
  while IFS= read -r -d '' arg; do
    base+=("${arg}")
  done < <(_ssh_base_opts)

  if [[ -n "${OMARCHY_BOX_SSH_KEY:-}" && -f "${OMARCHY_BOX_SSH_KEY}" ]]; then
    cmd=(ssh -i "${OMARCHY_BOX_SSH_KEY}" -o IdentitiesOnly=yes -o BatchMode=yes -p "${OMARCHY_BOX_SSH_PORT}" "${base[@]}" "${OMARCHY_BOX_SSH_USER}@${OMARCHY_BOX_SSH_HOST}")
  elif [[ -n "${OMARCHY_BOX_SSH_PASS:-}" ]] && command -v sshpass >/dev/null 2>&1; then
    cmd=(sshpass -p "${OMARCHY_BOX_SSH_PASS}" ssh -p "${OMARCHY_BOX_SSH_PORT}" "${base[@]}" "${OMARCHY_BOX_SSH_USER}@${OMARCHY_BOX_SSH_HOST}")
  else
    cmd=(ssh -p "${OMARCHY_BOX_SSH_PORT}" "${base[@]}" "${OMARCHY_BOX_SSH_USER}@${OMARCHY_BOX_SSH_HOST}")
  fi

  printf '%s\0' "${cmd[@]}"
}

_build_scp_cmd() {
  local -a cmd=()
  local -a base=()
  while IFS= read -r -d '' arg; do
    base+=("${arg}")
  done < <(_ssh_base_opts)

  if [[ -n "${OMARCHY_BOX_SSH_KEY:-}" && -f "${OMARCHY_BOX_SSH_KEY}" ]]; then
    cmd=(scp -i "${OMARCHY_BOX_SSH_KEY}" -o IdentitiesOnly=yes -P "${OMARCHY_BOX_SSH_PORT}" "${base[@]}")
  elif [[ -n "${OMARCHY_BOX_SSH_PASS:-}" ]] && command -v sshpass >/dev/null 2>&1; then
    cmd=(sshpass -p "${OMARCHY_BOX_SSH_PASS}" scp -P "${OMARCHY_BOX_SSH_PORT}" "${base[@]}")
  else
    cmd=(scp -P "${OMARCHY_BOX_SSH_PORT}" "${base[@]}")
  fi

  printf '%s\0' "${cmd[@]}"
}

_read_null_array() {
  local -n _out=$1
  _out=()
  while IFS= read -r -d '' arg; do
    _out+=("${arg}")
  done
}

run_in_box() {
  local -a cmd=()
  _read_null_array cmd < <(_build_ssh_cmd)
  "${cmd[@]}" "bash -lc $(printf '%q' "$*")"
}

copy_to_box() {
  local src="$1" dest="$2"
  local -a cmd=()
  _read_null_array cmd < <(_build_scp_cmd)
  "${cmd[@]}" -r -- "${src}" "${OMARCHY_BOX_SSH_USER}@${OMARCHY_BOX_SSH_HOST}:${dest}"
}

copy_from_box() {
  local src="$1" dest="$2"
  local -a cmd=()
  _read_null_array cmd < <(_build_scp_cmd)
  "${cmd[@]}" -r -- "${OMARCHY_BOX_SSH_USER}@${OMARCHY_BOX_SSH_HOST}:${src}" "${dest}"
}

wait_for_ssh() {
  echo -n "Waiting for SSH on ${OMARCHY_BOX_SSH_HOST}:${OMARCHY_BOX_SSH_PORT} "
  local start ts elapsed
  start=$(date +%s)
  while true; do
    if run_in_box "true" >/dev/null 2>&1; then
      echo "✓"
      return 0
    fi
    sleep 2
    echo -n "."
    ts=$(date +%s)
    elapsed=$(( ts - start ))
    if (( elapsed > OMARCHY_BOX_SSH_TIMEOUT_SECS )); then
      echo
      echo "ERROR: SSH did not become ready within ${OMARCHY_BOX_SSH_TIMEOUT_SECS}s" >&2
      return 1
    fi
  done
}
