#!/usr/bin/env bash

# Resolve and download official Omarchy release media (4.0+).

OMARCHY_BOX_CACHE_DIR="${OMARCHY_BOX_CACHE_DIR:-${OMARCHY_BOX_DATA_DIR}/cache}"
OMARCHY_BOX_STABLE_LATEST_URL="${OMARCHY_BOX_STABLE_LATEST_URL:-https://nightly.omarchy.org/stable/latest.json}"

omarchy_box_json_get() {
  # Usage: omarchy_box_json_get <file> <python-expr-on-obj-as-d>
  local file="$1"
  local expr="$2"
  python3 - "$file" "$expr" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
print(eval(sys.argv[2], {"d": d}))
PY
}

resolve_stable_manifest() {
  mkdir -p "${OMARCHY_BOX_CACHE_DIR}"
  local manifest="${OMARCHY_BOX_CACHE_DIR}/stable-latest.json"
  echo "Fetching stable release metadata…"
  curl -fsSL "${OMARCHY_BOX_STABLE_LATEST_URL}" -o "${manifest}.tmp"
  mv "${manifest}.tmp" "${manifest}"
  OMARCHY_BOX_RESOLVED_VERSION="$(omarchy_box_json_get "${manifest}" "d.get('version','')")"
  OMARCHY_BOX_RESOLVED_ISO_URL="$(omarchy_box_json_get "${manifest}" "d.get('url','')")"
  OMARCHY_BOX_RESOLVED_ISO_SHA="$(omarchy_box_json_get "${manifest}" "d.get('sha256','')")"
  OMARCHY_BOX_RESOLVED_QCOW_URL="$(omarchy_box_json_get "${manifest}" "d.get('vm',{}).get('url','') if isinstance(d.get('vm'), dict) else ''")"
  OMARCHY_BOX_RESOLVED_QCOW_SHA="$(omarchy_box_json_get "${manifest}" "d.get('vm',{}).get('sha256','') if isinstance(d.get('vm'), dict) else ''")"

  if [[ -z "${OMARCHY_BOX_RESOLVED_VERSION}" ]]; then
    echo "Could not determine the latest stable Omarchy version." >&2
    return 1
  fi

  omarchy_box_min_version "${OMARCHY_BOX_RESOLVED_VERSION}" || return 1

  # Official stable latest.json is x86-oriented. Build aarch64 ISO URL from the version.
  if [[ "${OMARCHY_BOX_GUEST_ARCH}" == "aarch64" ]]; then
    OMARCHY_BOX_RESOLVED_ISO_URL="https://iso.omarchy.org/omarchy-${OMARCHY_BOX_RESOLVED_VERSION}-aarch64.iso"
    OMARCHY_BOX_RESOLVED_ISO_SHA=""
    OMARCHY_BOX_RESOLVED_QCOW_URL=""
    OMARCHY_BOX_RESOLVED_QCOW_SHA=""
  fi
}

choose_media_kind() {
  local media="${OMARCHY_BOX_MEDIA:-auto}"
  case "${media}" in
    qcow|iso)
      OMARCHY_BOX_MEDIA_KIND="${media}"
      ;;
    auto)
      if [[ "${OMARCHY_BOX_GUEST_ARCH}" == "x86_64" && -n "${OMARCHY_BOX_RESOLVED_QCOW_URL}" ]]; then
        OMARCHY_BOX_MEDIA_KIND="qcow"
      else
        OMARCHY_BOX_MEDIA_KIND="iso"
      fi
      ;;
    *)
      echo "Unknown OMARCHY_BOX_MEDIA: ${media} (use auto, qcow, or iso)" >&2
      return 1
      ;;
  esac

  if [[ "${OMARCHY_BOX_MEDIA_KIND}" == "qcow" && -z "${OMARCHY_BOX_RESOLVED_QCOW_URL}" ]]; then
    echo "No official qcow2 is published for this arch/version; use ISO install instead." >&2
    echo "Set OMARCHY_BOX_MEDIA=iso or use a different guest arch." >&2
    return 1
  fi
}

download_file() {
  local url="$1"
  local dest="$2"
  local sha="${3:-}"

  mkdir -p "$(dirname "${dest}")"

  if [[ -f "${dest}" ]]; then
    if [[ -n "${sha}" ]]; then
      local actual
      actual="$(sha256sum "${dest}" | awk '{print $1}')"
      if [[ "${actual}" == "${sha}" ]]; then
        echo "Using cached $(basename "${dest}")"
        return 0
      fi
      echo "Cached file checksum mismatch; re-downloading $(basename "${dest}")…"
    else
      echo "Using cached $(basename "${dest}")"
      return 0
    fi
  fi

  echo "Downloading ${url}"
  echo "This may take a while (multi-GB)…"
  curl -fL --progress-bar -o "${dest}.partial" "${url}"
  mv "${dest}.partial" "${dest}"

  if [[ -n "${sha}" ]]; then
    local actual
    actual="$(sha256sum "${dest}" | awk '{print $1}')"
    if [[ "${actual}" != "${sha}" ]]; then
      echo "Checksum mismatch for ${dest}" >&2
      echo "Expected: ${sha}" >&2
      echo "Actual:   ${actual}" >&2
      rm -f "${dest}"
      return 1
    fi
  elif [[ -z "${sha}" ]]; then
    # Try sibling .sha256 when not provided in manifest.
    if curl -fsSL "${url}.sha256" -o "${dest}.sha256" 2>/dev/null; then
      (
        cd "$(dirname "${dest}")"
        sha256sum -c "$(basename "${dest}.sha256")"
      ) || return 1
    else
      echo "WARNING: no checksum available for $(basename "${dest}"); skipping verify." >&2
    fi
  fi
}

download_resolved_media() {
  resolve_stable_manifest
  choose_media_kind

  echo "Resolved Omarchy ${OMARCHY_BOX_RESOLVED_VERSION} (${OMARCHY_BOX_GUEST_ARCH}, media=${OMARCHY_BOX_MEDIA_KIND})"

  if [[ "${OMARCHY_BOX_MEDIA_KIND}" == "qcow" ]]; then
    OMARCHY_BOX_BASE_IMAGE="${OMARCHY_BOX_CACHE_DIR}/omarchy-${OMARCHY_BOX_RESOLVED_VERSION}.qcow2"
    download_file "${OMARCHY_BOX_RESOLVED_QCOW_URL}" "${OMARCHY_BOX_BASE_IMAGE}" "${OMARCHY_BOX_RESOLVED_QCOW_SHA}"
  else
    local iso_name
    iso_name="$(basename "${OMARCHY_BOX_RESOLVED_ISO_URL}")"
    OMARCHY_BOX_ISO="${OMARCHY_BOX_CACHE_DIR}/${iso_name}"
    download_file "${OMARCHY_BOX_RESOLVED_ISO_URL}" "${OMARCHY_BOX_ISO}" "${OMARCHY_BOX_RESOLVED_ISO_SHA}"
  fi
}
