# TensorFlow Lite Micro (TFLM) Library for ModusToolbox

## Overview
This library provides a pre-compiled static library for [TensorFlow Lite Micro](https://github.com/tensorflow/tflite-micro) for easy integration with [Infineon ModusToolbox](https://www.infineon.com/modustoolbox) projects. The official [TFLM library by Infineon](https://github.com/Infineon/ml-tflite-micro) only supports Infineon PSoC 6, hence this additional library.

No modifications have been made to the TensorFlow Lite Micro codebase. The purpose of this library is solely to provide a head start with TensorFlow Lite Micro inside ModusToolbox. By providing this pre-compiled library, the complexity of building the TensorFlow Lite Micro in a Linux or macOS environment and integrating it into ModusToolbox is removed.

Currently, libraries are only provided for the GNU Arm Embedded Toolchain (default of the ModusToolbox build system).

## Usage

### Adding the Library

To use the library in ModusToolbox v3.x, add a `manifest.loc` file to the `.modustoolbox` folder in your home directory. Inside this file, paste the following URI:

`https://github.com/jeldriks/mtb-tflite-micro/raw/main/mtb/manifests/mtb-super-manifest-supplement-tflm.xml`

### Quick Start

To add this library to a ModusToolbox project, install it from the Library Manager. Then add the following `DEFINES`, `COMPONENTS`, and `CXXFLAGS` to the application's Makefile:
- `DEFINES+= TF_LITE_STATIC_MEMORY`
- `COMPONENTS+= TFLM_CMSIS_NN`
  
  or with [CMSIS NN](https://arm-software.github.io/CMSIS-NN/latest/index.html) disabled: `COMPONENTS+= TFLM`
- `CXXFLAGS+= -std=c++11`

Please be aware that this library does not include any modifications/enhancements for Infineon microcontrollers or the ModusToolbox environment. Therefore, the usage might differ from Infineon code examples for machine learning applications.

The [Machine Learning (ML) Configurator](https://www.infineon.com/dgdl/Infineon-ModusToolbox_Machine_Learning_Configurator_Guide_0-UserManual-v04_00-EN.pdf) inside ModusToolbox is only available for PSoC 6. Therefore, model conversion and validation need to be performed outside of ModusToolbox. Refer to the official TensorFlow documentation for information on model [conversion](https://www.tensorflow.org/lite/microcontrollers/build_convert) and [quantization](https://www.tensorflow.org/lite/performance/post_training_quantization).

For more detailed instructions on the use of ModusToolbox, refer to [ModusToolbox tools package user guide](https://www.infineon.com/dgdl/Infineon-ModusToolbox_3.1_a_Tools_Package_User_Guide-GettingStarted-v01_00-EN.pdf).

### Application Code

Please refer to the TensorFlow documentation to learn how to [run inference](https://www.tensorflow.org/lite/microcontrollers/get_started_low_level#run_inference). A complete application example can be found in the [Hello World](https://github.com/tensorflow/tflite-micro/tree/main/tensorflow/lite/micro/examples/hello_world); refer to [hello_world_test.cc](https://github.com/tensorflow/tflite-micro/blob/main/tensorflow/lite/micro/examples/hello_world/hello_world_test.cc).

A [platform-specific implementation](https://github.com/tensorflow/tflite-micro/blob/main/tensorflow/lite/micro/cortex_m_generic/README.md) needs to be added, which is not covered in the above examples: registering a [debug log callback](https://github.com/tensorflow/tflite-micro/blob/main/tensorflow/lite/micro/cortex_m_generic/debug_log_callback.h).

## Building the Library

In case you want to update the library or build it for other cores:

* Make sure you're using Linux or macOS to build the library. Tested with Ubuntu 22.04 and macOS 14.
* Install required dependencies: A recent version of Make, Python, and ModusToolbox (only needed if the flag ``-m`` is used; see below). [Python packages](https://github.com/tensorflow/tflite-micro/blob/main/third_party/python_requirements.txt) required my TFLM.
* Navigate to the directory [mtb](./mtb/).
* For compatibility reasons, the build is fixed to a specific commit of the TFLM repo. To update the library to a newer version/commit, edit the variable ``TFLM_SHA`` in the below Bash script.
* Run the Bash script `build.sh` with the following flags:
  * `-a` (string): architecture (find the available architectures in the Bash script). In case no architecture is provided, all available architectures will be built.
  * `-c` (bool): enable CMSIS NN kernels.
  * `-m` (bool): use ModusToolbox GCC, instead of one downloaded on demand.

For example, to build the library for Cortex-M7 with FPU support, using CMSIS NN and ModusToolbox GCC, run the following command:

`./build.sh -a cortex-m7+fp -c true -m true`

To build for all architectures with CMSIS NN support:

`./build.sh -c true`
