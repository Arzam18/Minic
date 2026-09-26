#!/bin/bash
set -e

# Android ARM64 build for Minic.
# The workflow provides ANDROID_NDK_HOME/ANDROID_NDK_LATEST_HOME.
if [ -n "${ANDROID_NDK_HOME:-}" ] && [ -d "$ANDROID_NDK_HOME" ]; then
   NDK_ROOT="$ANDROID_NDK_HOME"
elif [ -n "${ANDROID_NDK_LATEST_HOME:-}" ] && [ -d "$ANDROID_NDK_LATEST_HOME" ]; then
   NDK_ROOT="$ANDROID_NDK_LATEST_HOME"
else
   NDK_ROOT="$(find /usr/local/lib/android/sdk/ndk -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -1)"
fi

if [ -z "$NDK_ROOT" ] || [ ! -d "$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin" ]; then
   echo "ERROR: Android NDK not found."
   exit 1
fi

ANDROID_NDK_PATH="$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"

export CXX="$ANDROID_NDK_PATH/aarch64-linux-android24-clang++"
export CC="$ANDROID_NDK_PATH/aarch64-linux-android24-clang"

if [ ! -x "$CXX" ]; then
   echo "ERROR: ARM64 Android compiler not found: $CXX"
   exit 1
fi

source "$(dirname "$0")/common"
cd_root

FATHOM_PRESENT=0
if [ -e Fathom/src/tbprobe.h ]; then
   FATHOM_PRESENT=1
   echo "Found Fathom lib, trying to build"
   "$(dirname "$0")/buildFathomAndroid.sh"
fi

do_title "Building Minic for Android ARM64 NEON"

# Keep Minic's existing NNUE SIMD implementation enabled, but target
# ARMv8-A/NEON instead of the old ARMv7 build.
OPT="-s -Wall -Wno-char-subscripts -Wno-reorder -Wno-missing-braces -Wno-constant-logical-operand $d -DNDEBUG -O3 $STDVERSION $n -Wno-unknown-pragmas -fconstexpr-steps=1000000000 -march=armv8-a"

# A Cortex-A76 target enables ARMv8-A NEON/FMA code generation and is
# appropriate for modern 64-bit Android phones.  It does not change the
# chess algorithm or NNUE weights.
if [ "${MINIC_ANDROID_CPU:-}" = "cortex-a76" ]; then
   OPT="$OPT -mcpu=cortex-a76"
fi

if [ $FATHOM_PRESENT = "1" ]; then
   lib=fathom_${v}_android.o
   OPT="$OPT $dir/Fathom/src/$lib -I$dir/Fathom/src"
fi

exe=${e}_${v}_android_arm64
echo "Building $exe"
echo "$OPT"

"$CXX" $OPT $STANDARDSOURCE -ISource -ISource/nnue    -o "$buildDir/$exe"    -static-libstdc++

echo "Built: $buildDir/$exe"
file "$buildDir/$exe" || true
ls -lh "$buildDir/$exe"
