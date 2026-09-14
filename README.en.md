# ohos-onnxruntime-libs

Pre-built [ONNX Runtime](https://github.com/microsoft/onnxruntime) shared libraries for OpenHarmony (OHOS).

## Background

ONNX Runtime doesn't provide official OpenHarmony prebuilt binaries. Flutter/ArkTS apps using PaddleOCR or other ML inference need `libonnxruntime.so`, but the Android NDK-built version fails on HarmonyOS due to musl libc++ incompatibility. This repository cross-compiles ONNX Runtime via GitHub Actions with OHOS-specific patches.

## Supported Architectures

| Arch | Description |
|------|-------------|
| `arm64-v8a` | Mainstream ARM64 (Huawei Mate/P series) |
| `armeabi-v7a` | 32-bit ARM (older TVs/tablets) |
| `x86_64` | Emulators / x86 dev boards |

## Quick Start

### 1. Trigger Build

Actions → Run workflow → specify ORT version (default: 1.29.1).

### 2. Download Artifacts

Actions → select run → Artifacts → download `onnxruntime-ohos-{arch}-{version}.zip`.

### 3. Integrate

```bash
unzip onnxruntime-ohos-arm64-v8a-1.29.1.zip -d entry/libs/arm64-v8a/
```

### 4. Create Release

```bash
git tag v1.29.1
git push origin v1.29.1
```

## Technical Details

- Based on [csukuangfj/onnxruntime-libs](https://github.com/csukuangfj/onnxruntime-libs) OHOS build approach
- Toolchain: OpenHarmony SDK (via [openharmony-rs/ohos-sdk](https://github.com/openharmony-rs/ohos-sdk))
- Build flags: `--compile-no-warning-as-error` for musl/clang compatibility
- Auto-patches: bfloat16_t, pthread_setaffinity_np, fp16/bf16 MLAS kernels, SBGEMM stubs

## License

MIT (same as ONNX Runtime).
