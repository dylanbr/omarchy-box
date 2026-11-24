#!/usr/bin/env bash

# Verify a file against a sibling .sha256 checksum file.
# Set OMARCHY_BOX_VERIFY_FILE to the path of the artifact.

ensure_runtime_dependencies

if [[ -z "${OMARCHY_BOX_VERIFY_FILE:-}" ]]; then
  echo "OMARCHY_BOX_VERIFY_FILE is not set." >&2
  exit 1
fi

checksum_file="${OMARCHY_BOX_VERIFY_FILE}.sha256"
if [[ ! -f "${checksum_file}" ]]; then
  echo "Checksum file not found: ${checksum_file}" >&2
  exit 1
fi

(
  cd "$(dirname "${OMARCHY_BOX_VERIFY_FILE}")"
  sha256sum -c "$(basename "${checksum_file}")"
)
