#!/usr/bin/env bash

echo "Instances in ${OMARCHY_BOX_DATA_DIR}/instances:"
found=false
if [[ -d "${OMARCHY_BOX_DATA_DIR}/instances" ]]; then
  shopt -s nullglob
  for dir in "${OMARCHY_BOX_DATA_DIR}/instances"/*; do
    [[ -d "${dir}" ]] || continue
    found=true
    name="$(basename "${dir}")"
    version="(not installed)"
    media="-"
    port="-"
    state="stopped"
    [[ -f "${dir}/.ready" ]] && version="$(tr -d '[:space:]' < "${dir}/.ready")"
    [[ -f "${dir}/.media" ]] && media="$(tr -d '[:space:]' < "${dir}/.media")"
    [[ -f "${dir}/.ssh_port" ]] && port="$(tr -d '[:space:]' < "${dir}/.ssh_port")"
    if [[ -f "${dir}/.qemu.pid" ]]; then
      pid="$(tr -d '[:space:]' < "${dir}/.qemu.pid")"
      if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
        state="running"
      else
        state="stale"
      fi
    fi
    disk="-"
    if [[ -f "${dir}/disk.qcow2" ]]; then
      disk="$(du -h "${dir}/disk.qcow2" 2>/dev/null | awk '{print $1}')"
    fi
    printf '  %-16s state=%-8s version=%-10s media=%-6s ssh=%-5s disk=%s\n' \
      "${name}" "${state}" "${version}" "${media}" "${port}" "${disk}"
  done
  shopt -u nullglob
fi
if [[ "${found}" != "true" ]]; then
  echo "  (none)"
fi

echo
cache="$(_omarchy_box_cache_dir)"
echo "Cached media in ${cache}:"
found=false
if [[ -d "${cache}" ]]; then
  shopt -s nullglob
  for f in "${cache}"/*.qcow2 "${cache}"/*.iso; do
    [[ -f "${f}" ]] || continue
    found=true
    printf '  %s (%s)\n' "$(basename "${f}")" "$(du -h "${f}" | awk '{print $1}')"
  done
  shopt -u nullglob
fi
if [[ "${found}" != "true" ]]; then
  echo "  (none)"
fi

echo
list_published_versions
