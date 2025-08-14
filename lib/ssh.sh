#!/usr/bin/env bash

ssh_base_opts=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o GlobalKnownHostsFile=/dev/null
  -o ConnectTimeout=3
)

ssh_opts=(
  -p "${OMARCHY_BOX_SSH_PORT}"
  ${ssh_base_opts[@]}
)

scp_opts=(
  -P "${OMARCHY_BOX_SSH_PORT}"
  ${ssh_base_opts[@]}
)

# Wrap ssh and scp in sshpass:
ssh_cmd=(sshpass -p "$OMARCHY_BOX_SSH_PASS" ssh "${ssh_opts[@]}" "${OMARCHY_BOX_SSH_USER}@${OMARCHY_BOX_SSH_HOST}")
scp_cmd=(sshpass -p "$OMARCHY_BOX_SSH_PASS" scp "${scp_opts[@]}")

run_in_box() {
  # Use bash -lc to get login-ish env and PATH expansion
  "${ssh_cmd[@]}" "bash -lc '$*'"
}

copy_to_box() {
  local src="$1" dest="$2"

  "${scp_cmd[@]}" -r -- "$src" "${OMARCHY_BOX_SSH_USER}@${OMARCHY_BOX_SSH_HOST}:$dest"
}

copy_from_vm() {
  local src="$1" dest="$2"
  "${scp_cmd[@]}" -r -- "${OMARCHY_BOX_SSH_USER}@${OMARCHY_BOX_SSH_HOST}:$src" "$dest"
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
