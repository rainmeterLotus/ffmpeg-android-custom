#!/usr/bin/env bash

case $ANDROID_ABI in
  armeabi-v7a)
    EXTRA_BUILD_CONFIGURATION_FLAGS=--enable-thumb
    ;;
  x86)
    # Disabling assembler optimizations, because they have text relocations
    EXTRA_BUILD_CONFIGURATION_FLAGS=--disable-asm
    ;;
  x86_64)
    EXTRA_BUILD_CONFIGURATION_FLAGS=--x86asmexe=${FAM_YASM}
    ;;
esac

if [ "$FFMPEG_GPL_ENABLED" = true ] ; then
    EXTRA_BUILD_CONFIGURATION_FLAGS="$EXTRA_BUILD_CONFIGURATION_FLAGS --enable-gpl"
fi

# Preparing flags for enabling requested libraries
ADDITIONAL_COMPONENTS=
for LIBARY_NAME in ${FFMPEG_EXTERNAL_LIBRARIES[@]}
do
  ADDITIONAL_COMPONENTS+=" --enable-$LIBARY_NAME"
done

# Referencing dependencies without pkgconfig
DEP_CFLAGS="-I${BUILD_DIR_EXTERNAL}/${ANDROID_ABI}/include"
DEP_LD_FLAGS="-L${BUILD_DIR_EXTERNAL}/${ANDROID_ABI}/lib $FFMPEG_EXTRA_LD_FLAGS"

# Everything that goes below ${EXTRA_BUILD_CONFIGURATION_FLAGS} is my project-specific.
# You are free to enable/disable whatever you actually need.
echo "--SYSROOT_PATH:$SYSROOT_PATH"
echo "--EXTRA_BUILD_CONFIGURATION_FLAGS:$EXTRA_BUILD_CONFIGURATION_FLAGS"
echo "--ADDITIONAL_COMPONENTS:$ADDITIONAL_COMPONENTS"
echo "--DEP_CFLAGS:$DEP_CFLAGS"
echo "--DEP_LD_FLAGS:$DEP_LD_FLAGS"
echo "--FFMPEG_EXTRA_LD_FLAGS:$FFMPEG_EXTRA_LD_FLAGS"
echo "--TARGET_TRIPLE_MACHINE_BINUTILS:$TARGET_TRIPLE_MACHINE_BINUTILS"

./configure \
  --prefix=${BUILD_DIR_FFMPEG}/${ANDROID_ABI} \
  --enable-cross-compile \
  --target-os=android \
  --arch=${TARGET_TRIPLE_MACHINE_BINUTILS} \
  --sysroot=${SYSROOT_PATH} \
  --cc=${FAM_CC} \
  --cxx=${FAM_CXX} \
  --ld=${FAM_LD} \
  --ar=${FAM_AR} \
  --as=${FAM_CC} \
  --nm=${FAM_NM} \
  --ranlib=${FAM_RANLIB} \
  --strip=${FAM_STRIP} \
  --extra-cflags="-O3 -fPIC $DEP_CFLAGS" \
  --extra-ldflags="$DEP_LD_FLAGS" \
  --enable-shared \
  --disable-static \
  --pkg-config=${PKG_CONFIG_EXECUTABLE} \
  ${EXTRA_BUILD_CONFIGURATION_FLAGS} \
  --disable-runtime-cpudetect \
  --disable-programs \
  --disable-avdevice \
  --disable-postproc \
  --disable-doc \
  --disable-debug \
  --disable-network \
  --disable-bsfs \
  --enable-pthreads \
  --enable-asm \
  --disable-neon \
  --enable-jni \
  --enable-mediacodec \
  --enable-decoder=h264_mediacodec \
  $ADDITIONAL_COMPONENTS || exit 1

${MAKE_EXECUTABLE} clean
${MAKE_EXECUTABLE} -j${HOST_NPROC}
${MAKE_EXECUTABLE} install
