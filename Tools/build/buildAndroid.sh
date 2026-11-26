#!/usr/bin/env bash
set -euo pipefail

# Android ARM64 build for Minic. This is a baseline ARMv8-A + NEON build.
# DotProd is intentionally not enabled: Minic's current NNUE kernels use
# float32 SIMD and int16 feature-transformer arithmetic, not int8 dot products.

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
export CXX="${ANDROID_NDK_PATH}/aarch64-linux-android24-clang++"
export CC="${ANDROID_NDK_PATH}/aarch64-linux-android24-clang"

if [[ ! -x "${CXX}" || ! -x "${CC}" ]]; then
    echo "ERROR: Android ARM64 API 24 Clang toolchain not found." >&2
    exit 1
fi

source "${SCRIPT_DIR}/common"
cd_root

FATHOM_PRESENT=0
if [[ -f Fathom/src/tbprobe.h ]]; then
    FATHOM_PRESENT=1
    echo "Found Fathom library; building its Android ARM64 object."
    "${SCRIPT_DIR}/buildFathomAndroid.sh"
fi

do_title "Building Minic for Android ARM64 NEON"

# AArch64 Android guarantees Advanced SIMD/NEON. Keep the ISA at ARMv8-A
# baseline so the executable does not require optional DotProd extensions.
OPT="-s -Wall -Wno-char-subscripts -Wno-reorder -Wno-missing-braces -Wno-constant-logical-operand ${d} -DUSE_SIMD_INTRIN -DNDEBUG -O3 ${STDVERSION} ${n} -Wno-unknown-pragmas -fconstexpr-steps=1000000000 -march=armv8-a+simd"

if [[ "${FATHOM_PRESENT}" == "1" ]]; then
    LIB="fathom_${v}_android.o"
    OPT="${OPT} ${dir}/Fathom/src/${LIB} -I${dir}/Fathom/src"
fi

EXE="${e}_${v}_android_arm64"
echo "Building ${EXE}"
echo "${OPT}"

# The NDK supplies Android system libraries; libc++ is linked statically so
# the user does not need libc++_shared.so alongside the UCI engine.
"${CXX}" ${OPT} ${STANDARDSOURCE} -ISource -ISource/nnue -o "${buildDir}/${EXE}" -static-libstdc++

echo "Built: ${buildDir}/${EXE}"
file "${buildDir}/${EXE}"
ls -lh "${buildDir}/${EXE}"
