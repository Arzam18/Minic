#!/bin/bash
set -e

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
export CC="$ANDROID_NDK_PATH/aarch64-linux-android24-clang"

if [ ! -x "$CC" ]; then
   echo "ERROR: ARM64 Android compiler not found: $CC"
   exit 1
fi

source "$(dirname "$0")/common"
cd_root

do_title "Building Fathom for Android ARM64"

cd "$dir/Fathom/src"

lib=fathom_${v}_android.o
echo "Building $lib"

OPT="-Wall -Wno-char-subscripts -Wno-unused-function -Wno-deprecated $d -DNDEBUG -O3 -flto -I."
"$CC" -c -std=gnu99 $OPT tbprobe.c -o "$lib"

cd -
