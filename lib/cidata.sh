#!/usr/bin/env bash

# Build an Omarchy unattended-install cidata image (FAT or ISO).

OMARCHY_BOX_DISK_GB="${OMARCHY_BOX_DISK_GB:-40}"
OMARCHY_BOX_HOSTNAME="${OMARCHY_BOX_HOSTNAME:-omarchy}"
OMARCHY_BOX_KB_LAYOUT="${OMARCHY_BOX_KB_LAYOUT:-us}"
OMARCHY_BOX_TIMEZONE="${OMARCHY_BOX_TIMEZONE:-UTC}"

ensure_cidata_dependencies() {
  if ! command -v openssl >/dev/null 2>&1; then
    echo "openssl is required to build install credentials." >&2
    exit 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to build install configuration." >&2
    exit 1
  fi
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

  python3 - "${dir}" \
    "${OMARCHY_BOX_SSH_USER}" "${hash}" "${OMARCHY_BOX_HOSTNAME}" \
    "${OMARCHY_BOX_KB_LAYOUT}" "${OMARCHY_BOX_TIMEZONE}" \
    "${efi_binary}" "${mirror_url}" \
    "${boot_start}" "${boot_size}" "${main_start}" "${main_size}" \
    "${ssh_pub}" <<'PY'
import json, pathlib, sys

(
    out_dir,
    user,
    password_hash,
    hostname,
    kb_layout,
    timezone,
    efi_binary,
    mirror_url,
    boot_start,
    boot_size,
    main_start,
    main_size,
    ssh_pub,
) = sys.argv[1:]

out = pathlib.Path(out_dir)
credentials = {
    "root_enc_password": password_hash,
    "users": [
        {
            "enc_password": password_hash,
            "groups": [],
            "sudo": True,
            "username": user,
        }
    ],
}
config = {
    "app_config": None,
    "archinstall-language": "English",
    "auth_config": {},
    "audio_config": {"audio": "pipewire"},
    "bootloader_config": {"bootloader": "Limine", "uki": False, "removable": False},
    "custom_commands": [],
    "omarchy_install": {
        "mode": "full_disk",
        "defer_provisioning": False,
        "target_mount": "/mnt",
        "boot": {
            "esp_mount": "/boot",
            "esp_path": "/EFI/limine",
            "efi_binary": efi_binary,
            "enable_fallback": True,
        },
        "storage": {"kernel": "linux-omarchy"},
    },
    "disk_config": {
        "config_type": "default_layout",
        "device_modifications": [
            {
                "device": "/dev/vda",
                "partitions": [
                    {
                        "btrfs": [],
                        "dev_path": None,
                        "flags": ["boot", "esp"],
                        "fs_type": "fat32",
                        "mount_options": [],
                        "mountpoint": "/boot",
                        "obj_id": "ea21d3f2-82bb-49cc-ab5d-6f81ae94e18d",
                        "size": {
                            "sector_size": {"unit": "B", "value": 512},
                            "unit": "B",
                            "value": int(boot_size),
                        },
                        "start": {
                            "sector_size": {"unit": "B", "value": 512},
                            "unit": "B",
                            "value": int(boot_start),
                        },
                        "status": "create",
                        "type": "primary",
                    },
                    {
                        "btrfs": [
                            {"mountpoint": "/", "name": "@"},
                            {"mountpoint": "/home", "name": "@home"},
                            {"mountpoint": "/var/log", "name": "@log"},
                            {"mountpoint": "/var/cache/pacman/pkg", "name": "@pkg"},
                        ],
                        "dev_path": None,
                        "flags": [],
                        "fs_type": "btrfs",
                        "mount_options": ["compress=zstd"],
                        "mountpoint": None,
                        "obj_id": "8c2c2b92-1070-455d-b76a-56263bab24aa",
                        "size": {
                            "sector_size": {"unit": "B", "value": 512},
                            "unit": "B",
                            "value": int(main_size),
                        },
                        "start": {
                            "sector_size": {"unit": "B", "value": 512},
                            "unit": "B",
                            "value": int(main_start),
                        },
                        "status": "create",
                        "type": "primary",
                    },
                ],
                "wipe": True,
            }
        ],
    },
    "hostname": hostname,
    "kernels": ["linux-omarchy"],
    "network_config": {"type": "iso"},
    "ntp": True,
    "parallel_downloads": 8,
    "script": None,
    "services": [],
    "swap": True,
    "timezone": timezone,
    "locale_config": {
        "kb_layout": kb_layout,
        "sys_enc": "UTF-8",
        "sys_lang": "en_US.UTF-8",
    },
    "mirror_config": {
        "custom_repositories": [],
        "custom_servers": [{"url": mirror_url}],
        "mirror_regions": {},
        "optional_repositories": [],
    },
    "packages": [
        "base-devel",
        "git",
        "omarchy-keyring",
        "omarchy-settings",
        "omarchy",
    ],
    "profile_config": {"gfx_driver": None, "greeter": None, "profile": {}},
    "version": "3.0.9",
}

(out / "user_credentials.json").write_text(json.dumps(credentials, indent=4) + "\n")
(out / "user_configuration.json").write_text(json.dumps(config, indent=4) + "\n")
(out / "user_encrypt_installation.txt").write_text("false\n")
(out / "authorized_keys").write_text(pathlib.Path(ssh_pub).read_text())
(out / "meta-data").write_text("instance-id: omarchy-box\n")
(out / "user-data").write_text(
    "#cloud-config\nusers: []\ndisable_root: false\nssh_authorized_keys:\n  - "
    + pathlib.Path(ssh_pub).read_text().strip()
    + "\n"
)
PY

  OMARCHY_BOX_CIDATA_IMAGE="${out_img}"
  OMARCHY_BOX_CIDATA_FORMAT="raw"
  _package_cidata_dir "${dir}" "${out_img}"
  local rc=$?
  rm -rf "${work}"
  return "${rc}"
}
