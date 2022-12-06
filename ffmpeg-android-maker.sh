#!/usr/bin/env bash

# Defining essential directories

# The root of the project
#下面的echo是日志输出
export BASE_DIR="$( cd "$( dirname "$0" )" && pwd )"
echo "----BASE_DIR:$BASE_DIR"
# Directory that contains source code for FFmpeg and its dependencies
# Each library has its own subdirectory
# Multiple versions of the same library can be stored inside librarie's directory
export SOURCES_DIR=${BASE_DIR}/sources
echo "----SOURCES_DIR:$SOURCES_DIR"
# Directory to place some statistics about the build.
# Currently - the info about Text Relocations
export STATS_DIR=${BASE_DIR}/stats
echo "----STATS_DIR:$STATS_DIR"
# Directory that contains helper scripts and
# scripts to download and build FFmpeg and each dependency separated by subdirectories
export SCRIPTS_DIR=${BASE_DIR}/scripts
echo "----SCRIPTS_DIR:$SCRIPTS_DIR"
# The directory to use by Android project
# All FFmpeg's libraries and headers are copied there
export OUTPUT_DIR=${BASE_DIR}/output
echo "----OUTPUT_DIR:$OUTPUT_DIR"
echo "----exec check-host-machine.sh--start---"
# 检查是否设置了 ANDROID_SDK_HOME和ANDROID_NDK_HOME
${SCRIPTS_DIR}/check-host-machine.sh || exit 1
echo "----exec check-host-machine.sh---end---"
# Directory to use as a place to build/install FFmpeg and its dependencies
BUILD_DIR=${BASE_DIR}/build
# Separate directory to build FFmpeg to
export BUILD_DIR_FFMPEG=$BUILD_DIR/ffmpeg
# All external libraries are installed to a single root
# to make easier referencing them when FFmpeg is being built.
export BUILD_DIR_EXTERNAL=$BUILD_DIR/external
echo "----BUILD_DIR_FFMPEG:$BUILD_DIR_FFMPEG"
echo "----BUILD_DIR_EXTERNAL:$BUILD_DIR_EXTERNAL"
# Function that copies *.so files and headers of the current ANDROID_ABI
# to the proper place inside OUTPUT_DIR
function prepareOutput() {
  OUTPUT_LIB=${OUTPUT_DIR}/lib/${ANDROID_ABI}
  echo "----prepareOutput OUTPUT_LIB:$OUTPUT_LIB"
  mkdir -p ${OUTPUT_LIB}
  cp ${BUILD_DIR_FFMPEG}/${ANDROID_ABI}/lib/*.so ${OUTPUT_LIB}

  OUTPUT_HEADERS=${OUTPUT_DIR}/include/${ANDROID_ABI}
  echo "----prepareOutput OUTPUT_HEADERS:$OUTPUT_HEADERS"
  mkdir -p ${OUTPUT_HEADERS}
  cp -r ${BUILD_DIR_FFMPEG}/${ANDROID_ABI}/include/* ${OUTPUT_HEADERS}
}

# Saving stats about text relocation presence.
# If the result file doesn't have 'TEXTREL' at all, then we are good.
# Otherwise the whole script is interrupted
function checkTextRelocations() {
  TEXT_REL_STATS_FILE=${STATS_DIR}/text-relocations.txt
  ${FAM_READELF} --dynamic ${BUILD_DIR_FFMPEG}/${ANDROID_ABI}/lib/*.so | grep 'TEXTREL\|File' >> ${TEXT_REL_STATS_FILE}

  if grep -q TEXTREL ${TEXT_REL_STATS_FILE}; then
    echo "There are text relocations in output files:"
    cat ${TEXT_REL_STATS_FILE}
    exit 1
  fi
}

# Actual work of the script

# Clearing previously created binaries
rm -rf ${BUILD_DIR}
rm -rf ${STATS_DIR}
rm -rf ${OUTPUT_DIR}
mkdir -p ${STATS_DIR}
mkdir -p ${OUTPUT_DIR}

# Exporting more necessary variabls
echo "----exec export-host-variables.sh--start---"
source ${SCRIPTS_DIR}/export-host-variables.sh
echo "----exec export-host-variables.sh--end---"

echo "----exec parse-arguments.sh--start---"
source ${SCRIPTS_DIR}/parse-arguments.sh
echo "----exec cparse-arguments.sh--end---"

# Treating FFmpeg as just a module to build after its dependencies
COMPONENTS_TO_BUILD=${EXTERNAL_LIBRARIES[@]}
COMPONENTS_TO_BUILD+=( "ffmpeg" )
echo "----COMPONENTS_TO_BUILD:${COMPONENTS_TO_BUILD[@]}"

# Get the source code of component to build
for COMPONENT in ${COMPONENTS_TO_BUILD[@]}
do
  echo "-----Getting source code of the component: ${COMPONENT}"
  SOURCE_DIR_FOR_COMPONENT=${SOURCES_DIR}/${COMPONENT}
  echo "-----Getting source code of the component SOURCE_DIR_FOR_COMPONENT: ${SOURCE_DIR_FOR_COMPONENT}"
  mkdir -p ${SOURCE_DIR_FOR_COMPONENT}
  cd ${SOURCE_DIR_FOR_COMPONENT}

  echo "----exec download.sh--start---"
  # Executing the component-specific script for downloading the source code
  source ${SCRIPTS_DIR}/${COMPONENT}/download.sh
  echo "----exec download.sh--end---"

  # The download.sh script has to export SOURCES_DIR_$COMPONENT variable
  # with actual path of the source code. This is done for possiblity to switch
  # between different verions of a component.
  # If it isn't set, consider SOURCE_DIR_FOR_COMPONENT as the proper value
  COMPONENT_SOURCES_DIR_VARIABLE=SOURCES_DIR_${COMPONENT}
  if [[ -z "${!COMPONENT_SOURCES_DIR_VARIABLE}" ]]; then
     export SOURCES_DIR_${COMPONENT}=${SOURCE_DIR_FOR_COMPONENT}
     echo "----SOURCES_DIR_COMPONENT:SOURCES_DIR_${COMPONENT}"
  fi

  # Returning to the rood directory. Just in case.
  cd ${BASE_DIR}
done


echo "----FFMPEG_ABIS_TO_BUILD:${FFMPEG_ABIS_TO_BUILD[@]}"
# Main build loop
for ABI in ${FFMPEG_ABIS_TO_BUILD[@]}
do
  # Exporting variables for the current ABI
  echo "----exec export-build-variables.sh----ABI:$ABI---start---"
  source ${SCRIPTS_DIR}/export-build-variables.sh ${ABI}
  echo "----exec export-build-variables.sh----ABI:$ABI---end---"

  echo "----COMPONENTS_TO_BUILD:${COMPONENTS_TO_BUILD[@]}"
  for COMPONENT in ${COMPONENTS_TO_BUILD[@]}
  do
    echo "----Building the component: ${COMPONENT}--ABI:$ABI"
    COMPONENT_SOURCES_DIR_VARIABLE=SOURCES_DIR_${COMPONENT}

    # Going to the actual source code directory of the current component
    cd ${!COMPONENT_SOURCES_DIR_VARIABLE}

    echo "----exec build.sh--$COMPONENT----ABI:$ABI---start---"
    # and executing the component-specific build script
    source ${SCRIPTS_DIR}/${COMPONENT}/build.sh || exit 1
    echo "----exec build.sh--$COMPONENT----ABI:$ABI---end---"
    # Returning to the root directory. Just in case.
    cd ${BASE_DIR}
  done

  checkTextRelocations || exit 1

  prepareOutput
done
