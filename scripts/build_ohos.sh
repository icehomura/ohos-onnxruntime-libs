#!/bin/bash
# Configure and build ONNX Runtime for one OHOS arch.
# Args:
#   $1 arch            (arm64-v8a | armeabi-v7a | x86_64)
#   $2 processor       (aarch64 | armv7 | x86_64)
#   $3 global flags    (quoted C/CXX/ASM flags)
#   $4 ORT source dir  (patched source tree)
#   $5 OHOS native dir (.../openharmony/native)
#   $6 FetchContent base dir (shared dependency cache)
#   $7 parallel make jobs
set -euo pipefail

ARCH="$1"; PROC="$2"; GLOBAL_FLAGS="$3"; SRC="$4"; NATIVE="$5"; FC_CACHE="$6"; JOBS="$7"
BUILD="$SRC/build-shared"

export PATH="$NATIVE/llvm/bin:$NATIVE/build-tools/cmake/bin:$PATH"
export OHOS_SDK_NATIVE_DIR="$NATIVE"

rm -rf "$BUILD"
mkdir -p "$BUILD" "$FC_CACHE"
cd "$BUILD"

cmake \
  -DCMAKE_TOOLCHAIN_FILE="$NATIVE/build/cmake/ohos.toolchain.cmake" \
  -DOHOS_ARCH="$ARCH" \
  -DOHOS_PLATFORM=OHOS \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_SYSTEM_PROCESSOR="$PROC" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$BUILD" \
  -Donnxruntime_CROSS_COMPILING=ON \
  -Donnxruntime_BUILD_SHARED_LIB=ON \
  -DABSL_ENABLE_INSTALL=ON \
  -DCMAKE_C_FLAGS="$GLOBAL_FLAGS" \
  -DCMAKE_CXX_FLAGS="$GLOBAL_FLAGS" \
  -DCMAKE_ASM_FLAGS="$GLOBAL_FLAGS" \
  -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--no-relax" \
  -DFETCHCONTENT_BASE_DIR="$FC_CACHE" \
  -DFETCHCONTENT_QUIET=OFF \
  --compile-no-warning-as-error \
  -Donnxruntime_BUILD_UNIT_TESTS=OFF \
  -Donnxruntime_RUN_ONNX_TESTS=OFF \
  -Donnxruntime_GENERATE_TEST_REPORTS=OFF \
  -Donnxruntime_USE_MIMALLOC=OFF \
  -Donnxruntime_ENABLE_PYTHON=OFF \
  -Donnxruntime_BUILD_CSHARP=OFF \
  -Donnxruntime_BUILD_JAVA=OFF \
  -Donnxruntime_BUILD_NODEJS=OFF \
  -Donnxruntime_BUILD_OBJC=OFF \
  -Donnxruntime_BUILD_APPLE_FRAMEWORK=OFF \
  -Donnxruntime_USE_DNNL=OFF \
  -Donnxruntime_USE_NNAPI_BUILTIN=OFF \
  -Donnxruntime_USE_RKNPU=OFF \
  -Donnxruntime_USE_LLVM=OFF \
  -Donnxruntime_ENABLE_MICROSOFT_INTERNAL=OFF \
  -Donnxruntime_USE_VITISAI=OFF \
  -Donnxruntime_USE_TENSORRT=OFF \
  -Donnxruntime_USE_TVM=OFF \
  -Donnxruntime_DISABLE_CONTRIB_OPS=OFF \
  -Donnxruntime_DISABLE_ML_OPS=OFF \
  -Donnxruntime_DISABLE_RTTI=OFF \
  -Donnxruntime_DISABLE_EXCEPTIONS=OFF \
  -Donnxruntime_MINIMAL_BUILD=OFF \
  -Donnxruntime_USE_DML=OFF \
  -Donnxruntime_USE_WINML=OFF \
  -Donnxruntime_ENABLE_LTO=OFF \
  -Donnxruntime_USE_ACL=OFF \
  -Donnxruntime_USE_ARMNN=OFF \
  -Donnxruntime_USE_JSEP=OFF \
  -Donnxruntime_ENABLE_TRAINING=OFF \
  -Donnxruntime_ENABLE_TRAINING_OPS=OFF \
  -Donnxruntime_ENABLE_TRAINING_APIS=OFF \
  -Donnxruntime_ENABLE_CPU_FP16_OPS=OFF \
  -Donnxruntime_USE_NCCL=OFF \
  -Donnxruntime_BUILD_BENCHMARKS=OFF \
  -Donnxruntime_USE_ROCM=OFF \
  -Donnxruntime_USE_MPI=OFF \
  -Donnxruntime_USE_XNNPACK=OFF \
  -Donnxruntime_USE_WEBNN=OFF \
  -Donnxruntime_USE_CANN=OFF \
  ../cmake

make -j"$JOBS"

echo "=== build finished: $ARCH ==="
ls -lh "$BUILD"/libonnxruntime.so*
