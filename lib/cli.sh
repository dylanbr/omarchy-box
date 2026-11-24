#!/usr/bin/env bash

# Parse omarchy-box CLI flags into environment overrides.
# Sets OMARCHY_BOX_ACTION to the selected command.

OMARCHY_BOX_ACTION=""
OMARCHY_BOX_FORCE="${OMARCHY_BOX_FORCE:-false}"

omarchy_box_parse_args() {
  OMARCHY_BOX_ACTION=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      start|build|download|clean|list|stop|status|help|usage)
        if [[ -n "${OMARCHY_BOX_ACTION}" ]]; then
          echo "Unexpected extra command: $1" >&2
          exit 1
        fi
        OMARCHY_BOX_ACTION="$1"
        shift
        ;;
      --version)
        OMARCHY_BOX_VERSION="${2:-}"
        [[ -n "${OMARCHY_BOX_VERSION}" ]] || { echo "--version needs a value" >&2; exit 1; }
        shift 2
        ;;
      --version=*)
        OMARCHY_BOX_VERSION="${1#*=}"
        shift
        ;;
      --media)
        OMARCHY_BOX_MEDIA="${2:-}"
        [[ -n "${OMARCHY_BOX_MEDIA}" ]] || { echo "--media needs a value" >&2; exit 1; }
        shift 2
        ;;
      --media=*)
        OMARCHY_BOX_MEDIA="${1#*=}"
        shift
        ;;
      --cpus|--cpu)
        OMARCHY_BOX_CPUS="${2:-}"
        shift 2
        ;;
      --cpus=*|--cpu=*)
        OMARCHY_BOX_CPUS="${1#*=}"
        shift
        ;;
      --memory|--ram)
        OMARCHY_BOX_RAM="${2:-}"
        shift 2
        ;;
      --memory=*|--ram=*)
        OMARCHY_BOX_RAM="${1#*=}"
        shift
        ;;
      --ssh-port)
        OMARCHY_BOX_SSH_PORT="${2:-}"
        OMARCHY_BOX_SSH_PORT_EXPLICIT=true
        shift 2
        ;;
      --ssh-port=*)
        OMARCHY_BOX_SSH_PORT="${1#*=}"
        OMARCHY_BOX_SSH_PORT_EXPLICIT=true
        shift
        ;;
      --instance|--name)
        OMARCHY_BOX_INSTANCE="${2:-}"
        shift 2
        ;;
      --instance=*|--name=*)
        OMARCHY_BOX_INSTANCE="${1#*=}"
        shift
        ;;
      --user)
        OMARCHY_BOX_SSH_USER="${2:-}"
        shift 2
        ;;
      --user=*)
        OMARCHY_BOX_SSH_USER="${1#*=}"
        shift
        ;;
      --password)
        OMARCHY_BOX_SSH_PASS="${2:-}"
        shift 2
        ;;
      --password=*)
        OMARCHY_BOX_SSH_PASS="${1#*=}"
        shift
        ;;
      --ssh-key)
        OMARCHY_BOX_SSH_KEY="${2:-}"
        shift 2
        ;;
      --ssh-key=*)
        OMARCHY_BOX_SSH_KEY="${1#*=}"
        shift
        ;;
      --hostname)
        OMARCHY_BOX_HOSTNAME="${2:-}"
        shift 2
        ;;
      --hostname=*)
        OMARCHY_BOX_HOSTNAME="${1#*=}"
        shift
        ;;
      --keyboard)
        OMARCHY_BOX_KB_LAYOUT="${2:-}"
        shift 2
        ;;
      --keyboard=*)
        OMARCHY_BOX_KB_LAYOUT="${1#*=}"
        shift
        ;;
      --timezone)
        OMARCHY_BOX_TIMEZONE="${2:-}"
        shift 2
        ;;
      --timezone=*)
        OMARCHY_BOX_TIMEZONE="${1#*=}"
        shift
        ;;
      --disk-size|--disk-gb)
        OMARCHY_BOX_DISK_GB="${2:-}"
        shift 2
        ;;
      --disk-size=*|--disk-gb=*)
        OMARCHY_BOX_DISK_GB="${1#*=}"
        shift
        ;;
      --display)
        OMARCHY_BOX_DISPLAY="${2:-}"
        shift 2
        ;;
      --display=*)
        OMARCHY_BOX_DISPLAY="${1#*=}"
        shift
        ;;
      --guest-arch)
        OMARCHY_BOX_GUEST_ARCH="${2:-}"
        shift 2
        ;;
      --guest-arch=*)
        OMARCHY_BOX_GUEST_ARCH="${1#*=}"
        shift
        ;;
      --force)
        OMARCHY_BOX_FORCE=true
        shift
        ;;
      --ephemeral)
        OMARCHY_BOX_EPHEMERAL=true
        shift
        ;;
      --all)
        OMARCHY_BOX_ALL=true
        shift
        ;;
      --allow-emulation)
        OMARCHY_BOX_ALLOW_EMULATION=true
        shift
        ;;
      -h|--help)
        OMARCHY_BOX_ACTION="help"
        shift
        ;;
      *)
        echo "Unknown argument: $1" >&2
        echo "Try: $0 help" >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "${OMARCHY_BOX_ACTION}" ]]; then
    OMARCHY_BOX_ACTION="usage"
  fi
}
