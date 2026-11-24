#!/usr/bin/env bash

# Detect host OS/arch and the Omarchy guest arch we will run.
# Guest arch matches the host by default (native virt). Cross-arch
# (x86_64 guest on ARM) is opt-in and intentionally slow (TCG).

OMARCHY_BOX_HOST_OS="$(uname -s)"
OMARCHY_BOX_HOST_ARCH="$(uname -m)"

case "${OMARCHY_BOX_HOST_ARCH}" in
  x86_64|amd64)
    OMARCHY_BOX_HOST_ARCH="x86_64"
    ;;
  aarch64|arm64)
    OMARCHY_BOX_HOST_ARCH="aarch64"
    ;;
  *)
    echo "Unsupported host architecture: ${OMARCHY_BOX_HOST_ARCH}" >&2
    exit 1
    ;;
esac

case "${OMARCHY_BOX_HOST_OS}" in
  Linux|Darwin)
    ;;
  *)
    echo "Unsupported host OS: ${OMARCHY_BOX_HOST_OS}" >&2
    echo "Omarchy Box currently supports macOS and Linux only." >&2
    exit 1
    ;;
esac

# Guest arch defaults to host arch. Override with OMARCHY_BOX_GUEST_ARCH=x86_64|aarch64.
OMARCHY_BOX_GUEST_ARCH="${OMARCHY_BOX_GUEST_ARCH:-${OMARCHY_BOX_HOST_ARCH}}"

case "${OMARCHY_BOX_GUEST_ARCH}" in
  x86_64|amd64)
    OMARCHY_BOX_GUEST_ARCH="x86_64"
    ;;
  aarch64|arm64)
    OMARCHY_BOX_GUEST_ARCH="aarch64"
    ;;
  *)
    echo "Unsupported guest architecture: ${OMARCHY_BOX_GUEST_ARCH}" >&2
    exit 1
    ;;
esac

if [[ "${OMARCHY_BOX_GUEST_ARCH}" == "x86_64" ]]; then
  OMARCHY_BOX_QEMU_BIN="qemu-system-x86_64"
else
  OMARCHY_BOX_QEMU_BIN="qemu-system-aarch64"
fi

OMARCHY_BOX_NATIVE_VIRT=true
if [[ "${OMARCHY_BOX_GUEST_ARCH}" != "${OMARCHY_BOX_HOST_ARCH}" ]]; then
  OMARCHY_BOX_NATIVE_VIRT=false
  if [[ "${OMARCHY_BOX_ALLOW_EMULATION:-}" != "true" ]]; then
    echo "Refusing to run a ${OMARCHY_BOX_GUEST_ARCH} guest on ${OMARCHY_BOX_HOST_ARCH} without emulation." >&2
    echo "Native virt is preferred (guest arch matches host)." >&2
    echo "To force slow TCG emulation, set OMARCHY_BOX_ALLOW_EMULATION=true." >&2
    exit 1
  fi
  echo "WARNING: emulating ${OMARCHY_BOX_GUEST_ARCH} on ${OMARCHY_BOX_HOST_ARCH} (TCG). Expect poor performance." >&2
fi

omarchy_box_min_version() {
  # Omarchy Box only targets Omarchy 4.0+ (cidata autoinstall era).
  local version="${1#v}"
  local major="${version%%.*}"
  if [[ -z "${major}" || "${major}" -lt 4 ]]; then
    echo "Omarchy Box requires Omarchy 4.0 or newer (got: ${1})." >&2
    return 1
  fi
  return 0
}
