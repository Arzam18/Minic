#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ -n "${ANDROID_NDK_HOME:-}" && -d "${ANDROID_NDK_HOME}" ]]; then
    NDK_ROOT="${ANDROID_NDK_HOME}"
elif [[ -n "${ANDROID_NDK_LATEST_HOME:-}" && -d "${ANDROID_NDK_LATEST_HOME}" ]]; then
    NDK_ROOT="${ANDROID_NDK_LATEST_HOME}"
else
    SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/usr/local/lib/android/sdk}}"
    NDK_ROOT="$(find "${SDK_ROOT}/ndk" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)"
fi

if [[ -z "${NDK_ROOT:-}" || ! -d "${NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin" ]]; then
    echo "ERROR: Android NDK not found. Set ANDROID_NDK_HOME." >&2
    exit 1
fi

ANDROID_NDK_PATH="${NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin"
export CC="${ANDROID_NDK_PATH}/aarch64-linux-android24-clang"

if [[ ! -x "${CC}" ]]; then
    echo "ERROR: Android ARM64 API 24 C compiler not found: ${CC}" >&2
    exit 1
fi

source "${SCRIPT_DIR}/common"
cd_root

do_title "Building Fathom for Android ARM64"

cd "${dir}/Fathom/src"

LIB="fathom_${v}_android.o"
echo "Building ${LIB}"

OPT="-Wall -Wno-char-subscripts -Wno-unused-function -Wno-deprecated ${d} -DNDEBUG -O3 -I."
"${CC}" -c -std=gnu99 ${OPT} tbprobe.c -o "${LIB}"

cd "${dir}"
