#!/usr/bin/env bash

# SSH helpers for Omarchy Box.
# Prefer key-based auth. Password auth via sshpass is optional fallback only.

ssh_base_opts=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o GlobalKnownHostsFile=/dev/null
  -o ConnectTimeout=3
)

ssh_opts=(
  -p "${OMARCHY_BOX_SSH_PORT}"
  "${ssh_base_opts[@]}"
)

scp_opts=(
  -P "${OMARCHY_BOX_SSH_PORT}"
  "${ssh_base_opts[@]}"
)

_build_ssh_cmd() {
  local -a cmd=()

  if [[ -n "${OMARCHY_BOX_SSH_KEY:-}" && -f "${OMARCHY_BOX_SSH_KEY}" ]]; then
    cmd=(ssh -i "${OMARCHY_BOX_SSH_KEY}" -o IdentitiesOnly=yes -o BatchMode=yes "${ssh_opts[@]}" "${OMARCHY_BOX_SSH_USER}@${OMARCHY_BOX_SSH_HOST}")
  elif [[ -n "${OMARCHY_BOX_SSH_PASS:-}" ]] && command -v sshpass >/dev/null 2>&1; then
    cmd=(sshpass -p "${OMARCHY_BOX_SSH_PASS}" ssh "${ssh_opts[@]}" "${OMARCHY_BOX_SSH_USER}@${OMARCHY_BOX_SSH_HOST}")
  else
    cmd=(ssh "${ssh_opts[@]}" "${OMARCHY_BOX_SSH_USER}@${OMARCHY_BOX_SSH_HOST}")
  fi

  printf '%s\0' "${cmd[@]}"
}

_build_scp_cmd() {
  local -a cmd=()

  if [[ -n "${OMARCHY_BOX_SSH_KEY:-}" && -f "${OMARCHY_BOX_SSH_KEY}" ]]; then
    cmd=(scp -i "${OMARCHY_BOX_SSH_KEY}" -o IdentitiesOnly=yes "${scp_opts[@]}")
  elif [[ -n "${OMARCHY_BOX_SSH_PASS:-}" ]] && command -v sshpass >/dev/null 2>&1; then
    cmd=(sshpass -p "${OMARCHY_BOX_SSH_PASS}" scp "${scp_opts[@]}")
  else
    cmd=(scp "${scp_opts[@]}")
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
  # Use bash -lc for login-ish env and PATH expansion
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
