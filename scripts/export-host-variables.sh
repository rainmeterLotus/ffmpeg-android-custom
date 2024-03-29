#!/usr/bin/env bash

# Defining a toolchain directory's name according to the current OS.
# Assume that proper version of NDK is installed
# and is referenced by ANDROID_NDK_HOME environment variable
# 依据编译系统确定编译工具链的目录名字
#macOS	darwin-x86_64
#Linux	linux-x86_64
#32 位 Windows	windows
#64 位 Windows	windows-x86_64
case "$OSTYPE" in
  darwin*)  HOST_TAG="darwin-x86_64" ;;
  linux*)   HOST_TAG="linux-x86_64" ;;
  msys)
    case "$(uname -m)" in
      x86_64) HOST_TAG="windows-x86_64" ;;
      i686)   HOST_TAG="windows" ;;
    esac
  ;;
esac

#检查当前系统输出cup的个数，这就是你们经常网上看到的那种编译 make -j8,开启编译cpu线程数
#可以看下scripts/ffmpeg/build.sh最后用到了HOST_NPROC变量
if [[ $OSTYPE == "darwin"* ]]; then
  HOST_NPROC=$(sysctl -n hw.physicalcpu)
else
  HOST_NPROC=$(nproc)
fi

# The variable is used as a path segment of the toolchain path
export HOST_TAG=$HOST_TAG
echo "---HOST_TAG:$HOST_TAG"

# Number of physical cores in the system to facilitate parallel assembling
export HOST_NPROC=$HOST_NPROC
echo "---HOST_NPROC:$HOST_NPROC"

# Using CMake from the Android SDK
export CMAKE_EXECUTABLE=${ANDROID_SDK_HOME}/cmake/3.10.2.4988404/bin/cmake
echo "---CMAKE_EXECUTABLE:$CMAKE_EXECUTABLE"

# Using Build machine's Make, because Android NDK's Make (before r21) doesn't work properly in MSYS2 on Windows
export MAKE_EXECUTABLE=$(which make)
echo "---MAKE_EXECUTABLE:$MAKE_EXECUTABLE"

# Using Build machine's Ninja. It is used for libdav1d building. Needs to be installed
export NINJA_EXECUTABLE=$(which ninja)
echo "---NINJA_EXECUTABLE:$NINJA_EXECUTABLE"

# Meson is used for libdav1d building. Needs to be installed
export MESON_EXECUTABLE=$(which meson)
echo "---MESON_EXECUTABLE:$MESON_EXECUTABLE"

# Nasm is used for libdav1d and libx264 building. Needs to be installed
export NASM_EXECUTABLE=$(which nasm)
echo "---NASM_EXECUTABLE:$NASM_EXECUTABLE"

# A utility to properly pick shared libraries by FFmpeg's configure script. Needs to be installed
export PKG_CONFIG_EXECUTABLE=$(which pkg-config)
echo "---PKG_CONFIG_EXECUTABLE:$PKG_CONFIG_EXECUTABLE"
