#!/usr/bin/env bash

# Build an Omarchy unattended-install cidata image (FAT or ISO).

OMARCHY_BOX_DISK_GB="${OMARCHY_BOX_DISK_GB:-40}"
OMARCHY_BOX_HOSTNAME="${OMARCHY_BOX_HOSTNAME:-omarchy}"
OMARCHY_BOX_KB_LAYOUT="${OMARCHY_BOX_KB_LAYOUT:-us}"
OMARCHY_BOX_TIMEZONE="${OMARCHY_BOX_TIMEZONE:-UTC}"

ensure_cidata_dependencies() {
  if ! command -v openssl >/dev/null 2>&1; then
    echo "openssl is required for ISO installs (to hash the user password)." >&2
    exit 1
  fi
}

# Escape a string for inclusion in a JSON double-quoted value.
omarchy_box_json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "${s}"
}

_package_cidata_dir() {
  local dir="$1"
  local dest="$2"

  if command -v mkfs.vfat >/dev/null 2>&1 && command -v mcopy >/dev/null 2>&1; then
    rm -f "${dest}"
    if command -v truncate >/dev/null 2>&1; then
      truncate -s 4M "${dest}"
    else
      dd if=/dev/zero of="${dest}" bs=1m count=4 status=none 2>/dev/null || dd if=/dev/zero of="${dest}" bs=1048576 count=4
    fi
    mkfs.vfat -n CIDATA "${dest}" >/dev/null
    mcopy -i "${dest}" "${dir}"/* ::/
    OMARCHY_BOX_CIDATA_FORMAT="raw"
    return 0
  fi

  if command -v hdiutil >/dev/null 2>&1; then
    local iso="${dest%.img}.iso"
    rm -f "${iso}"
    hdiutil makehybrid -iso -joliet -default-volume-name cidata -o "${iso}" "${dir}" >/dev/null
    OMARCHY_BOX_CIDATA_IMAGE="${iso}"
    OMARCHY_BOX_CIDATA_FORMAT="iso"
    return 0
  fi

  if command -v xorriso >/dev/null 2>&1; then
    local iso="${dest%.img}.iso"
    rm -f "${iso}"
    xorriso -as mkisofs -V cidata -o "${iso}" -joliet -rock "${dir}" >/dev/null
    OMARCHY_BOX_CIDATA_IMAGE="${iso}"
    OMARCHY_BOX_CIDATA_FORMAT="iso"
    return 0
  fi

  if command -v genisoimage >/dev/null 2>&1 || command -v mkisofs >/dev/null 2>&1; then
    local iso="${dest%.img}.iso"
    local mkiso
    mkiso="$(command -v genisoimage || command -v mkisofs)"
    rm -f "${iso}"
    "${mkiso}" -output "${iso}" -volid cidata -joliet -rock "${dir}" >/dev/null
    OMARCHY_BOX_CIDATA_IMAGE="${iso}"
    OMARCHY_BOX_CIDATA_FORMAT="iso"
    return 0
  fi

  echo "Could not build a cidata image." >&2
  echo "Install one of: dosfstools+mtools, xorriso/genisoimage, or use macOS hdiutil." >&2
  return 1
}

build_cidata_image() {
  local out_img="${1}"
  local ssh_pub="${2}"
  local work dir hash efi_binary mirror_url
  local user_json hostname_json kb_json tz_json efi_json mirror_json ssh_line

  ensure_cidata_dependencies

  if [[ ! -f "${ssh_pub}" ]]; then
    echo "SSH public key not found: ${ssh_pub}" >&2
    return 1
  fi

  work="$(mktemp -d "${OMARCHY_BOX_INSTANCE_DIR}/cidata-build.XXXXXX")"
  dir="${work}/cidata"
  mkdir -p "${dir}"

  hash="$(openssl passwd -6 "${OMARCHY_BOX_SSH_PASS}")"

  if [[ "${OMARCHY_BOX_GUEST_ARCH}" == "aarch64" ]]; then
    efi_binary="limine_aa64.efi"
    mirror_url='https://arm-stable-mirror.omarchy.org/$arch/$repo'
  else
    efi_binary="limine_x64.efi"
    mirror_url='https://stable-mirror.omarchy.org/$repo/os/$arch'
  fi

  local disk_bytes=$((OMARCHY_BOX_DISK_GB * 1024 * 1024 * 1024))
  local mib=$((1024 * 1024)) gib=$((1024 * 1024 * 1024))
  local boot_start=$mib boot_size=$((2 * gib))
  local main_start=$((boot_size + boot_start))
  local main_size=$((disk_bytes - main_start - mib))

  user_json="$(omarchy_box_json_escape "${OMARCHY_BOX_SSH_USER}")"
  hostname_json="$(omarchy_box_json_escape "${OMARCHY_BOX_HOSTNAME}")"
  kb_json="$(omarchy_box_json_escape "${OMARCHY_BOX_KB_LAYOUT}")"
  tz_json="$(omarchy_box_json_escape "${OMARCHY_BOX_TIMEZONE}")"
  efi_json="$(omarchy_box_json_escape "${efi_binary}")"
  mirror_json="$(omarchy_box_json_escape "${mirror_url}")"
  # Password hashes are safe ASCII; still escape for JSON.
  local hash_json
  hash_json="$(omarchy_box_json_escape "${hash}")"
  ssh_line="$(tr -d '\r\n' < "${ssh_pub}")"

  cat >"${dir}/user_credentials.json" <<EOF
{
    "root_enc_password": "${hash_json}",
    "users": [
        {
            "enc_password": "${hash_json}",
            "groups": [],
            "sudo": true,
            "username": "${user_json}"
        }
    ]
}
EOF

  cat >"${dir}/user_configuration.json" <<EOF
{
    "app_config": null,
    "archinstall-language": "English",
    "auth_config": {},
    "audio_config": { "audio": "pipewire" },
    "bootloader_config": { "bootloader": "Limine", "uki": false, "removable": false },
    "custom_commands": [],
    "omarchy_install": {
        "mode": "full_disk",
        "defer_provisioning": false,
        "target_mount": "/mnt",
        "boot": {
            "esp_mount": "/boot",
            "esp_path": "/EFI/limine",
            "efi_binary": "${efi_json}",
            "enable_fallback": true
        },
        "storage": { "kernel": "linux-omarchy" }
    },
    "disk_config": {
        "config_type": "default_layout",
        "device_modifications": [
            {
                "device": "/dev/vda",
                "partitions": [
                    {
                        "btrfs": [],
                        "dev_path": null,
                        "flags": [ "boot", "esp" ],
                        "fs_type": "fat32",
                        "mount_options": [],
                        "mountpoint": "/boot",
                        "obj_id": "ea21d3f2-82bb-49cc-ab5d-6f81ae94e18d",
                        "size": { "sector_size": { "unit": "B", "value": 512 }, "unit": "B", "value": ${boot_size} },
                        "start": { "sector_size": { "unit": "B", "value": 512 }, "unit": "B", "value": ${boot_start} },
                        "status": "create",
                        "type": "primary"
                    },
                    {
                        "btrfs": [
                            { "mountpoint": "/", "name": "@" },
                            { "mountpoint": "/home", "name": "@home" },
                            { "mountpoint": "/var/log", "name": "@log" },
                            { "mountpoint": "/var/cache/pacman/pkg", "name": "@pkg" }
                        ],
                        "dev_path": null,
                        "flags": [],
                        "fs_type": "btrfs",
                        "mount_options": [ "compress=zstd" ],
                        "mountpoint": null,
                        "obj_id": "8c2c2b92-1070-455d-b76a-56263bab24aa",
                        "size": { "sector_size": { "unit": "B", "value": 512 }, "unit": "B", "value": ${main_size} },
                        "start": { "sector_size": { "unit": "B", "value": 512 }, "unit": "B", "value": ${main_start} },
                        "status": "create",
                        "type": "primary"
                    }
                ],
                "wipe": true
            }
        ]
    },
    "hostname": "${hostname_json}",
    "kernels": [ "linux-omarchy" ],
    "network_config": { "type": "iso" },
    "ntp": true,
    "parallel_downloads": 8,
    "script": null,
    "services": [],
    "swap": true,
    "timezone": "${tz_json}",
    "locale_config": { "kb_layout": "${kb_json}", "sys_enc": "UTF-8", "sys_lang": "en_US.UTF-8" },
    "mirror_config": {
        "custom_repositories": [],
        "custom_servers": [
            {"url": "${mirror_json}"}
        ],
        "mirror_regions": {},
        "optional_repositories": []
    },
    "packages": [
        "base-devel",
        "git",
        "omarchy-keyring",
        "omarchy-settings",
        "omarchy"
    ],
    "profile_config": { "gfx_driver": null, "greeter": null, "profile": {} },
    "version": "3.0.9"
}
EOF

  printf 'false\n' >"${dir}/user_encrypt_installation.txt"
  cp "${ssh_pub}" "${dir}/authorized_keys"
  printf 'instance-id: omarchy-box\n' >"${dir}/meta-data"
  printf '#cloud-config\nusers: []\ndisable_root: false\nssh_authorized_keys:\n  - %s\n' "${ssh_line}" >"${dir}/user-data"

  OMARCHY_BOX_CIDATA_IMAGE="${out_img}"
  OMARCHY_BOX_CIDATA_FORMAT="raw"
  _package_cidata_dir "${dir}" "${out_img}"
  local rc=$?
  rm -rf "${work}"
  return "${rc}"
}
