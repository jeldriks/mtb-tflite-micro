#!/bin/bash

# Copyright 2023 - 2024 Jeldrik Schröer. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ========================================================================


# This scripts compiles the TensorFlow Lite Micro (TFLM) library for different Cortex-M cores
# and packages it for an easy integration into Infineon ModusToolbox v3.x projects.

# Note: building under Windows is currently not fully supported by the TFLM project. 
# Therefore, building using WSL (Windows Subsystem for Linux), Linux or macOS is required.

######################
# Update this commit for switching to another version of TFLM
TFLM_SHA="b766947f5a0b8f34dbe1a12b904c99d524b291d3"
######################


# Locate ModusToolbox tools folders in default installation location
if [[ $(uname -s) == *"Darwin"* ]]; then
    CY_TOOLS_PATHS=/Applications/ModusToolbox/tools_*
else
    CY_TOOLS_PATHS=$HOME/ModusToolbox/tools_*
fi

ROOT_DIR=$(pwd)/../

# Get the ./gcc/bin/ folder of the latest MTB tools
CY_TOOLS_PATH=$CY_TOOLS_PATHS[-1]
TOOLCHAIN_DIR=$(echo $CY_TOOLS_PATH)/gcc/bin/

# Define standard options for building TFLM
INIT_OPTIONS="TARGET=cortex_m_generic"

# State variables
HAS_RUN_ONCE=false


# Clone the TFLM repo and get dependencies
function tflm_setup {
    cd $ROOT_DIR/mtb/

    if ! [ -d "tflite-micro" ]; then
        git clone https://github.com/tensorflow/tflite-micro.git
    fi

    cd tflite-micro

    git fetch
    git checkout $TFLM_SHA

    # Download the required third party dependencies
    if ! $HAS_RUN_ONCE; then
        make -f tensorflow/lite/micro/tools/make/Makefile $OPTIONS third_party_downloads
    fi
}

# Copy required header files
function tflm_copy_headers {
    # To save time, run the header files only once per run
    if $HAS_RUN_ONCE; then
        return
    fi

    cd $ROOT_DIR/mtb/tflite-micro

    # Get the path for storing the header files
    if [[ "$OPTIONS" == *"cmsis_nn"* ]]; then
        INCLUDE_DIR=$ROOT_DIR/COMPONENT_TFLM_CMSIS_NN/include
    else
        INCLUDE_DIR=$ROOT_DIR/COMPONENT_TFLM/include
    fi

    # Delete the directory, in case it exists
    rm -rf $INCLUDE_DIR

    # Get the required header files
    HEADERS=$(make -f tensorflow/lite/micro/tools/make/Makefile $OPTIONS list_library_headers)
    HEADERS+=" "
    HEADERS+=$(make -f tensorflow/lite/micro/tools/make/Makefile $OPTIONS list_third_party_headers)
    HEADERS=$(echo $HEADERS | tr " " "\n")

    # Copy the required header files to the dir ../../../tflm-include/
    for file in $HEADERS
    do
        DIR=$INCLUDE_DIR/$(dirname $file)
        BASENAME=$(basename $file)
        mkdir -p $DIR
        cp $file $DIR
    done
}

# Build TFLM
function tflm_build {
    cd $ROOT_DIR/mtb/tflite-micro

    # Construct a path, depending on the desired configuration

    # With or without CMSIS NN kernels
    if [[ "$OPTIONS" == *"cmsis_nn"* ]]; then
        SUB_1=COMPONENT_TFLM_CMSIS_NN
    else
        SUB_1=COMPONENT_TFLM
    fi

    # ARCH
    if [[ "$OPTIONS" == *"cortex-m0plus"* ]]; then
        SUB_2=COMPONENT_CM0P
    elif [[ "$OPTIONS" == *"cortex-m0"* ]]; then
        SUB_2=COMPONENT_CM0
    elif [[ "$OPTIONS" == *"cortex-m3"* ]]; then
        SUB_2=COMPONENT_CM3
    elif [[ "$OPTIONS" == *"cortex-m4"* ]]; then
        SUB_2=COMPONENT_CM4
    elif [[ "$OPTIONS" == *"cortex-m7"* ]]; then
        SUB_2=COMPONENT_CM7
    fi

    # With or without FPU
    if [[ "$OPTIONS" == *"+fp"* ]]; then
        SUB_3=COMPONENT_HARDFP
    else
        SUB_3=COMPONENT_SOFTFP
    fi

    # Assemble the full path and create the folder
    LIBDIR=$ROOT_DIR/$SUB_1/$SUB_2/$SUB_3/TOOLCHAIN_GCC_ARM/

    # Delete the directory, in case it exists; then re-create
    rm -rf $LIBDIR
    mkdir -p $LIBDIR

    # Determine 3/4 of the total CPU core count
    avail_cpu_cores=$(nproc --all)
    cpu_cores=$(($avail_cpu_cores/2 + $avail_cpu_cores/4))

    # Build the library
    make -j $cpu_cores -f tensorflow/lite/micro/tools/make/Makefile $OPTIONS LIBDIR=$LIBDIR microlite
}

# Build a specific configuration
#   argument 1: target arch (string)
#   argument 2: additional options
function tflm_build_option {
    OPTIONS="$INIT_OPTIONS TARGET_ARCH=$1 $2"

    echo "Using the following options: $OPTIONS"

    tflm_setup
    tflm_copy_headers
    tflm_build

    HAS_RUN_ONCE=true
}

######################

# Get the flags, used when calling the script
while getopts ":a:c:m:" flag; do
    case $flag in
        a)  arch=${OPTARG};;
        c)  if $OPTARG; then
                # Add CMSIS NN kernels
                KERNELS+=" OPTIMIZED_KERNEL_DIR=cmsis_nn"
            fi;;
        m)  if $OPTARG; then
                # Use MTB GCC instead of one that is downloaded on demand
                INIT_OPTIONS+=" TARGET_TOOLCHAIN_ROOT=$TOOLCHAIN_DIR"
            fi;;
    esac
done

if [ -z "${arch}" ]; then
    # No specific arch has been set using a flag, so build all available archs

    # Find all available options here:
    # https://github.com/tensorflow/tflite-micro/blob/main/tensorflow/lite/micro/tools/make/targets/cortex_m_generic_makefile.inc
    archs=(
        "cortex-m0"           # Cortex M0
        "cortex-m0plus"       # Cortex M0+
        "cortex-m3"           # Cortex M3
        "cortex-m4"           # Cortex M4
        "cortex-m4+fp"        # Cortex M4 + FPU
        "cortex-m7"           # Cortex M7
        "cortex-m7+fp"        # Cortex M7 + FPU
    )

    for arch in ${archs[@]}; do
        tflm_build_option $arch $KERNELS
    done
else
    # Build the specific arch, specified by flag
    tflm_build_option $arch $KERNELS
fi
