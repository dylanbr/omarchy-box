#!/usr/bin/env bash

# Resolve and download official Omarchy release media (4.0+).
# Parses Omarchy's stable latest.json with sed/awk only (no python/jq).

OMARCHY_BOX_STABLE_LATEST_URL="${OMARCHY_BOX_STABLE_LATEST_URL:-https://nightly.omarchy.org/stable/latest.json}"
OMARCHY_BOX_RELEASES_URL="${OMARCHY_BOX_RELEASES_URL:-https://api.github.com/repos/omacom/omarchy/releases?per_page=40}"

_omarchy_box_cache_dir() {
  echo "${OMARCHY_BOX_CACHE_DIR:-${OMARCHY_BOX_DATA_DIR}/cache}"
}

# First top-level JSON string value for a given key (pretty-printed objects).
omarchy_box_json_string() {
  local file="$1"
  local key="$2"
  sed -n "s/^[[:space:]]*\"${key}\":[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "${file}" | head -n 1
}

# String value for a key inside the top-level "vm" object.
omarchy_box_json_vm_string() {
  local file="$1"
  local key="$2"
  awk -v key="$key" '
    /"vm"[[:space:]]*:/ { in_vm = 1; next }
    in_vm && /^[[:space:]]*}/ { exit }
    in_vm {
      prefix = "\"" key "\":"
      idx = index($0, prefix)
      if (idx == 0) next
      rest = substr($0, idx + length(prefix))
      sub(/^[[:space:]]*"/, "", rest)
      quote = index(rest, "\"")
      if (quote > 0) {
        print substr(rest, 1, quote - 1)
        exit
      }
    }
  ' "${file}"
}

# True if version $1 >= version $2 (sort -V).
omarchy_box_version_ge() {
  local left="${1#v}"
  local right="${2#v}"
  local first
  first="$(printf '%s\n%s\n' "${right}" "${left}" | sort -V | head -n 1)"
  [[ "${first}" == "${right}" ]]
}

normalize_omarchy_version() {
  local version="${1:-latest}"
  version="${version#v}"
  if [[ "${version}" == "latest" || -z "${version}" ]]; then
    echo "latest"
  else
    echo "${version}"
  fi
}

# ISO filename rules:
# - 4.5.0+: omarchy-VERSION-x86.iso / omarchy-VERSION-aarch64.iso
# - earlier 4.x: omarchy-VERSION.iso (x86 only)
iso_url_for_version() {
  local version="$1"
  local arch="$2"
  local name

  version="${version#v}"
  if omarchy_box_version_ge "${version}" "4.5.0"; then
    if [[ "${arch}" == "aarch64" ]]; then
      name="omarchy-${version}-aarch64.iso"
    else
      name="omarchy-${version}-x86.iso"
    fi
  else
    if [[ "${arch}" == "aarch64" ]]; then
      echo "No official aarch64 ISO is published for Omarchy ${version} (need 4.5.0+)." >&2
      return 1
    fi
    name="omarchy-${version}.iso"
  fi

  echo "https://iso.omarchy.org/${name}"
}

fetch_stable_latest_json() {
  local cache_dir manifest
  cache_dir="$(_omarchy_box_cache_dir)"
  mkdir -p "${cache_dir}"
  manifest="${cache_dir}/stable-latest.json"
  echo "Fetching stable release metadata…" >&2
  curl -fsSL "${OMARCHY_BOX_STABLE_LATEST_URL}" -o "${manifest}.tmp"
  mv "${manifest}.tmp" "${manifest}"
  echo "${manifest}"
}

resolve_stable_manifest() {
  local manifest
  manifest="$(fetch_stable_latest_json)"

  OMARCHY_BOX_RESOLVED_VERSION="$(omarchy_box_json_string "${manifest}" version)"
  OMARCHY_BOX_RESOLVED_ISO_URL="$(omarchy_box_json_string "${manifest}" url)"
  OMARCHY_BOX_RESOLVED_ISO_SHA="$(omarchy_box_json_string "${manifest}" sha256)"
  OMARCHY_BOX_RESOLVED_QCOW_URL="$(omarchy_box_json_vm_string "${manifest}" url)"
  OMARCHY_BOX_RESOLVED_QCOW_SHA="$(omarchy_box_json_vm_string "${manifest}" sha256)"

  if [[ -z "${OMARCHY_BOX_RESOLVED_VERSION}" ]]; then
    echo "Could not determine the latest stable Omarchy version." >&2
    return 1
  fi

  omarchy_box_min_version "${OMARCHY_BOX_RESOLVED_VERSION}" || return 1

  if [[ "${OMARCHY_BOX_GUEST_ARCH}" == "aarch64" ]]; then
    OMARCHY_BOX_RESOLVED_ISO_URL="$(iso_url_for_version "${OMARCHY_BOX_RESOLVED_VERSION}" aarch64)"
    OMARCHY_BOX_RESOLVED_ISO_SHA=""
    OMARCHY_BOX_RESOLVED_QCOW_URL=""
    OMARCHY_BOX_RESOLVED_QCOW_SHA=""
  fi
}

resolve_versioned_media() {
  local requested latest_manifest latest_version

  requested="$(normalize_omarchy_version "${OMARCHY_BOX_VERSION:-latest}")"
  OMARCHY_BOX_REQUESTED_VERSION="${requested}"

  if [[ "${requested}" == "latest" ]]; then
    resolve_stable_manifest
    return
  fi

  omarchy_box_min_version "${requested}" || return 1

  OMARCHY_BOX_RESOLVED_VERSION="${requested}"
  OMARCHY_BOX_RESOLVED_ISO_URL="$(iso_url_for_version "${requested}" "${OMARCHY_BOX_GUEST_ARCH}")" || return 1
  OMARCHY_BOX_RESOLVED_ISO_SHA=""
  OMARCHY_BOX_RESOLVED_QCOW_URL=""
  OMARCHY_BOX_RESOLVED_QCOW_SHA=""

  # If this version is the current stable latest, reuse qcow metadata when available.
  latest_manifest="$(fetch_stable_latest_json)"
  latest_version="$(omarchy_box_json_string "${latest_manifest}" version)"
  if [[ "${latest_version}" == "${requested}" && "${OMARCHY_BOX_GUEST_ARCH}" == "x86_64" ]]; then
    OMARCHY_BOX_RESOLVED_ISO_URL="$(omarchy_box_json_string "${latest_manifest}" url)"
    OMARCHY_BOX_RESOLVED_ISO_SHA="$(omarchy_box_json_string "${latest_manifest}" sha256)"
    OMARCHY_BOX_RESOLVED_QCOW_URL="$(omarchy_box_json_vm_string "${latest_manifest}" url)"
    OMARCHY_BOX_RESOLVED_QCOW_SHA="$(omarchy_box_json_vm_string "${latest_manifest}" sha256)"
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
    echo "No official qcow2 is available for Omarchy ${OMARCHY_BOX_RESOLVED_VERSION} on ${OMARCHY_BOX_GUEST_ARCH}." >&2
    echo "Use --media iso, or --version latest on x86_64." >&2
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
  else
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
  resolve_versioned_media
  choose_media_kind

  echo "Resolved Omarchy ${OMARCHY_BOX_RESOLVED_VERSION} (${OMARCHY_BOX_GUEST_ARCH}, media=${OMARCHY_BOX_MEDIA_KIND})"

  local cache_dir
  cache_dir="$(_omarchy_box_cache_dir)"

  if [[ "${OMARCHY_BOX_MEDIA_KIND}" == "qcow" ]]; then
    OMARCHY_BOX_BASE_IMAGE="${cache_dir}/omarchy-${OMARCHY_BOX_RESOLVED_VERSION}.qcow2"
    download_file "${OMARCHY_BOX_RESOLVED_QCOW_URL}" "${OMARCHY_BOX_BASE_IMAGE}" "${OMARCHY_BOX_RESOLVED_QCOW_SHA}"
  else
    local iso_name
    iso_name="$(basename "${OMARCHY_BOX_RESOLVED_ISO_URL}")"
    OMARCHY_BOX_ISO="${cache_dir}/${iso_name}"
    download_file "${OMARCHY_BOX_RESOLVED_ISO_URL}" "${OMARCHY_BOX_ISO}" "${OMARCHY_BOX_RESOLVED_ISO_SHA}"
  fi
}

list_published_versions() {
  echo "Published Omarchy 4.x releases (from GitHub):"
  curl -fsSL "${OMARCHY_BOX_RELEASES_URL}" \
    | tr ',' '\n' \
    | sed -n 's/.*"tag_name":[[:space:]]*"\(v[^"]*\)".*/\1/p' \
    | while read -r tag; do
        case "${tag}" in
          v4.*|4.*)
            case "${tag}" in
              *rc*|*alpha*|*beta*) continue ;;
            esac
            echo "  ${tag#v}"
            ;;
        esac
      done
}
