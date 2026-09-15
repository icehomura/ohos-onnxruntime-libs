#!/bin/bash
# Patch a pristine ONNX Runtime source tree for OpenHarmony cross compilation.
# Args: $1 = arch (arm64-v8a|armeabi-v7a|x86_64)
#       $2 = absolute path to ORT source tree (patched in place)
#       $3 = absolute path to OHOS native SDK (.../openharmony/native)
set -euo pipefail

ARCH="$1"
SRC="$2"
NATIVE="$3"

case "$ARCH" in
  arm64-v8a)   PROC=aarch64 ;;
  armeabi-v7a) PROC=armv7 ;;
  x86_64)      PROC=x86_64 ;;
  *) echo "ERROR: unknown arch '$ARCH'"; exit 1 ;;
esac

echo "=== Patching ORT tree at $SRC for $ARCH (processor $PROC) ==="
cd "$SRC"

# ---------- 1. cmake-level adjustments ----------
pushd cmake
# Remove shared-object versioning -> single libonnxruntime.so (no .so.1 symlinks)
sed -i '/SOVERSION/d' onnxruntime.cmake
sed -i '/onnxruntime PROPERTIES VERSION/d' onnxruntime.cmake

# Force target system/processor at the very top of the top-level cmake
{
  echo "set(CMAKE_SYSTEM_PROCESSOR ${PROC} CACHE STRING \"\" FORCE)"
  echo "set(CMAKE_SYSTEM_NAME Linux CACHE STRING \"\" FORCE)"
  cat CMakeLists.txt
} > CMakeLists.txt.new && mv CMakeLists.txt.new CMakeLists.txt

# Default options: no unit tests, build shared lib
sed -i 's/"Build ONNXRuntime unit tests" ON/"Build ONNXRuntime unit tests" OFF/' CMakeLists.txt
sed -i 's/"Build a shared library" OFF/"Build a shared library" ON/' CMakeLists.txt
popd

# ---------- 2. drop unsupported x86 CET flag for clang ----------
sed -i 's/-fcf-protection//g' tools/ci_build/build.py

# ---------- 3. musl has no pthread_setaffinity_np ----------
sed -i 's/#if !defined(__APPLE__) && !defined(__ANDROID__) && !defined(__wasm__) && !defined(_AIX)/#if 0/' \
  onnxruntime/core/platform/posix/env.cc

# ---------- 4. MLAS: guard out aarch64+linux bf16/fp16 intrinsic paths on OHOS ----------
find onnxruntime/core/mlas -type f \( -name '*.h' -o -name '*.cpp' -o -name '*.cc' \) -print0 \
  | xargs -0 sed -i 's/#if defined(__aarch64__) && defined(__linux__)/#if defined(__aarch64__) \&\& defined(__linux__) \&\& !defined(__OHOS__)/g'

# Prevent MLAS_F16VEC_INTRINSICS_SUPPORTED from being defined
sed -i 's/#if !defined(__APPLE__)/#if !defined(__APPLE__) \&\& !defined(__OHOS__)/g' \
  onnxruntime/core/mlas/inc/mlas.h

# ORT >= 1.30 gates the whole SBGEMM/bf16 API (declarations + bfloat16_t usage)
# on MLAS_SBGEMM_AVAILABLE, which is only defined for ARM64+Linux. Disable it on
# OHOS so the unsupported bf16 declarations drop out and the no-op stubs below
# apply instead. No-op on versions without this exact guard.
sed -i 's|#if defined(MLAS_TARGET_ARM64) && defined(__linux__)|#if defined(MLAS_TARGET_ARM64) \&\& defined(__linux__) \&\& !defined(__OHOS__)|g' \
  onnxruntime/core/mlas/inc/mlas.h

# ---------- 5. remove fp16/bf16-only translation units from MLAS build ----------
pushd cmake
for pat in \
  'hqnbitgemm_kernel_neon_fp16_8bit\.cpp' \
  'hqnbitgemm_kernel_neon_fp16\.cpp' \
  'rotary_embedding_kernel_neon_fp16\.cpp' \
  'halfgemm_kernel_neon_fp16\.cpp' \
  'softmax_kernel_neon_fp16\.cpp' \
  'eltwise_kernel_neon_fp16\.cpp' \
  'erf_neon_fp16\.' \
  'gelu_neon_fp16\.' \
  'activate_fp16\.cpp' \
  'pooling_fp16\.cpp' \
  'cast_kernel_neon\.cpp' \
  'HalfGemmKernelNeon\.S' \
  'sbgemm_kernel_neon\.cpp' \
  'sbconv_kernel_neon\.cpp' \
  'SbgemmKernelNeon\.S' \
  'SconvDepthwiseKernelNeonBf16\.S' \
  'SconvKernelNeonBf16\.S' \
  'SconvPointwiseKernelNeonBf16\.S' \
  'HAS_ARM64_BFLOAT16\|HAS_ARM64_FLOAT16' \
  'message.*FATAL.*BFLOAT16\|message.*FATAL.*FLOAT16' \
  'cvtfp16Avx\.S' \
  'cvtfp16a\.S' \
  'cvtfp16Avx\.asm' ; do
  sed -i "/${pat}/d" onnxruntime_mlas.cmake
done
popd

# ---------- 6. platform.cpp: drop x86 fp16 cast kernel reference ----------
sed -i 's/this->CastF16ToF32Kernel = &MlasCastF16ToF32KernelSse;/this->CastF16ToF32Kernel = nullptr;/' \
  onnxruntime/core/mlas/lib/platform.cpp

# ---------- 7. matmul: disable bf16 fast path ----------
sed -i 's/use_fastmath_mode_ = (config_ops == "1") && MlasBf16AccelerationSupported();/use_fastmath_mode_ = false;/' \
  onnxruntime/core/providers/cpu/math/matmul.h

# ---------- 8. SBGEMM / bf16 stubs (their upstream declarations are guarded out in #4) ----------
MLAS_H=onnxruntime/core/mlas/inc/mlas.h
if ! grep -q 'OHOS_SBGEMM_STUBS' "$MLAS_H"; then
cat >> "$MLAS_H" <<'EOF'

#ifdef __OHOS__
// OHOS (clang-15) lacks ARM bf16/fp16 NEON intrinsics: provide no-op stubs.
#define OHOS_SBGEMM_STUBS 1
struct MLAS_SBGEMM_POSTPROCESSOR {};
struct MLAS_SBGEMM_DATA_PARAMS {
  const void *A; const void *B; const float *Bias; float *C;
  size_t lda; size_t ldb; size_t ldc;
  const MLAS_SBGEMM_POSTPROCESSOR *OutputProcessor;
  bool AIsfp32; bool BIsfp32; bool ZeroMode; bool BIsPacked;
};
static inline size_t MlasSBGemmPackBSize(CBLAS_TRANSPOSE,CBLAS_TRANSPOSE,bool,size_t,size_t,const MLAS_BACKEND_KERNEL_SELECTOR_CONFIG*){return 0;}
static inline void MlasSBGemmConvertPackB(CBLAS_TRANSPOSE,CBLAS_TRANSPOSE,bool,size_t,size_t,const float*,size_t,void*,const MLAS_BACKEND_KERNEL_SELECTOR_CONFIG*){}
static inline void MlasSBGemmBatch(CBLAS_TRANSPOSE,CBLAS_TRANSPOSE,size_t,size_t,size_t,size_t,const MLAS_SBGEMM_DATA_PARAMS*,MLAS_THREADPOOL*,const MLAS_BACKEND_KERNEL_SELECTOR_CONFIG*){}
static inline bool MlasBf16AccelerationSupported(){return false;}
#endif
EOF
fi

# ---------- 9. C++20 -> C++17 compatibility for clang-15 libc++ ----------
find onnxruntime -type f \( -name '*.cpp' -o -name '*.h' -o -name '*.cc' \) -print0 \
  | xargs -0 sed -i 's/std::make_unique_for_overwrite/std::make_unique/g'

# ---------- 10. structured bindings -> C++17-compatible form ----------
tf=onnxruntime/core/session/model_editor_c_api.cc
sed -i 's/auto \[ptr_it, ptr_inserted\] = graph->initializer_ptrs.insert(tensor);/auto insert_res_1 = graph->initializer_ptrs.insert(tensor); auto ptr_it = insert_res_1.first; auto ptr_inserted = insert_res_1.second;/g' "$tf"
sed -i 's/auto \[ptr_it, ptr_inserted\] = graph->node_ptrs.insert(node);/auto insert_res_2 = graph->node_ptrs.insert(node); auto ptr_it = insert_res_2.first; auto ptr_inserted = insert_res_2.second;/g' "$tf"

# ---------- 11. patch OHOS SDK toolchain file (idempotent) ----------
TC="$NATIVE/build/cmake/ohos.toolchain.cmake"
sed -i 's/set(UNIX TRUE CACHE BOOL FROCE)/set(UNIX TRUE CACHE BOOL "Force UNIX" FORCE)/g' "$TC"
sed -i 's/CMAKE_SYSTEM_NAME OHOS/CMAKE_SYSTEM_NAME Linux/g' "$TC"
sed -i 's|set(CMAKE_C_FLAGS "${OHOS_C_COMPILER_FLAGS} ${CMAKE_C_FLAGS} -D__MUSL__")|set(CMAKE_C_FLAGS "${OHOS_C_COMPILER_FLAGS} ${CMAKE_C_FLAGS} -D__MUSL__ -D__OHOS__")|' "$TC"
sed -i 's|set(CMAKE_CXX_FLAGS "${OHOS_CXX_COMPILER_FLAGS} ${CMAKE_CXX_FLAGS} -D__MUSL__")|set(CMAKE_CXX_FLAGS "${OHOS_CXX_COMPILER_FLAGS} ${CMAKE_CXX_FLAGS} -D__MUSL__ -D__OHOS__")|' "$TC"

echo "=== Patch complete for $ARCH ==="
