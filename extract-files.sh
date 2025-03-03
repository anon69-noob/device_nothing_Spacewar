#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2023 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=Spacewar
VENDOR=nothing

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_FIRMWARE=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-firmware )
                ONLY_FIRMWARE=true
                ;;
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        vendor/etc/init/netmgrd.rc)
            sed -i "/modprobe/d" "${2}"
            ;;
        vendor/lib64/hw/fingerprint.lahaina.so)
            "${PATCHELF}" --set-soname "fingerprint.lahaina.so" "${2}"
            ;;
        vendor/lib64/libgf_hal.so)
            sed -i "s|ro.boot.flash.locked|ro.bootloader.locked|g" "${2}"
            ;;
        vendor/lib64/hw/com.qti.chi.override.so)
            grep -q libcamera_metadata_shim.so "${2}" || "${PATCHELF}" --add-needed libcamera_metadata_shim.so "${2}"
            ;;
	vendor/etc/media_codecs.xml|vendor/etc/media_codecs_lahaina.xml|vendor/etc/media_codecs_lahaina_vendor.xml|vendor/etc/media_codecs_yupik_v1.xml)
            sed -Ei "/media_codecs_(google_audio|google_telephony|vendor_audio)/d" "${2}"
            ;;
    esac
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

if [ -z "${ONLY_FIRMWARE}" ]; then
   extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

if [ "${ONLY_FIRMWARE}" ]; then
   extract_firmware "${MY_DIR}/proprietary-firmware.txt" "${SRC}"
fi

"${MY_DIR}/setup-makefiles.sh"
