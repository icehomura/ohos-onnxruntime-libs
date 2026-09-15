#!/bin/bash
# Collect, normalize SONAME and verify the built libonnxruntime.so.
# Args: $1 arch  $2 version  $3 ORT source dir  $4 output dir
set -euo pipefail

ARCH="$1"; VERSION="$2"; SRC="$3"; OUT="$4"
BUILD="$SRC/build-shared"

rm -rf "$OUT"
mkdir -p "$OUT/include"

SO="$(find "$BUILD" -maxdepth 1 -name 'libonnxruntime.so*' -type f | head -1)"
[ -n "$SO" ] || { echo "ERROR: libonnxruntime.so not found in $BUILD"; find "$BUILD" -name 'libonnxruntime.so*'; exit 1; }
cp "$SO" "$OUT/libonnxruntime.so"

# Public C API header
cp "$SRC/include/onnxruntime/core/session/onnxruntime_c_api.h" "$OUT/include/" 2>/dev/null || true

# Force a clean SONAME so OHOS dlopen("libonnxruntime.so") resolves directly
patchelf --set-soname libonnxruntime.so "$OUT/libonnxruntime.so"

echo "=== artifact verification: $ARCH ($VERSION) ==="
file "$OUT/libonnxruntime.so"
readelf -h "$OUT/libonnxruntime.so" | grep -E 'Class|Machine'
echo "--- dynamic section ---"
readelf -d "$OUT/libonnxruntime.so" | grep -E 'NEEDED|SONAME'
echo "--- exported ORT API symbols (sanity) ---"
readelf -W --dyn-syms "$OUT/libonnxruntime.so" | grep -c 'OrtGetApiBase' || true
ls -lh "$OUT"
