# ohos-onnxruntime-libs

Pre-built [ONNX Runtime](https://github.com/microsoft/onnxruntime) shared libraries for OpenHarmony (OHOS). A single run builds all three ABIs: `arm64-v8a`, `armeabi-v7a`, and `x86_64`.

## Background

ONNX Runtime provides no official OpenHarmony binaries. Flutter/ArkTS apps doing ML inference (e.g. PaddleOCR handwriting recognition) need `libonnxruntime.so`, but an Android-NDK build fails to `dlopen` on HarmonyOS because of musl/libc++ incompatibility. This repository cross-compiles an OHOS-compatible shared library via GitHub Actions.

## Supported Architectures

| Arch | Cross compiler (bundled in the OHOS SDK) | Notes |
|------|------------------------------------------|-------|
| `arm64-v8a` | `aarch64-unknown-linux-ohos-clang` | Mainstream ARM64 devices (Huawei Mate/P series) |
| `armeabi-v7a` | `armv7-unknown-linux-ohos-clang` | 32-bit ARM (older TVs/tablets) |
| `x86_64` | `x86_64-unknown-linux-ohos-clang` | Emulators / x86 boards |

> Note the 32-bit ARM prefix is `armv7-` (not `armv7a-`). All three compilers ship in the same OHOS Native SDK.

## Quick Start

### 1. Trigger a build

Actions → "Build ONNX Runtime for OpenHarmony" → Run workflow → set the ORT version (default 1.29.1). The three ABIs build in parallel (`fail-fast: false`).

### 2. Download artifacts

Each ABI produces `onnxruntime-ohos-{arch}-{version}` containing:

```
libonnxruntime.so            # SONAME=libonnxruntime.so, no .so.1 version suffix
include/onnxruntime_c_api.h  # Public C API header
```

### 3. Integrate

```bash
unzip onnxruntime-ohos-arm64-v8a-1.29.1.zip -d entry/libs/arm64-v8a/
```

### 4. Publish a release

Pushing a `vX.Y.Z` tag builds all three ABIs and aggregates them into one GitHub Release:

```bash
git tag v1.29.1
git push origin v1.29.1
```

### 5. Automatic upstream sync

The "Sync upstream ORT releases" workflow polls `microsoft/onnxruntime` every 6 hours. When a new stable release that has not been published here is found, it automatically builds all three ABIs for that version and creates the matching release. You can also run it manually from the Actions tab.

## Repository layout

```
.github/workflows/ci.yml             # 3-ABI build + aggregated release (also a reusable workflow)
.github/workflows/sync-upstream.yml  # Polls upstream for new releases and triggers the build
scripts/patch_ohos.sh                # Idempotent OHOS compatibility patches
scripts/build_ohos.sh                # cmake configure + cross compile
scripts/collect_ohos.sh              # Collect .so, fix SONAME, verify ELF arch and NEEDED libs
```

## Technical Details

- Based on the OHOS approach in [csukuangfj/onnxruntime-libs](https://github.com/csukuangfj/onnxruntime-libs)
- Toolchain: OpenHarmony Native SDK 5.0.0.71 (clang 15.0.4) from [openharmony-rs/ohos-sdk](https://github.com/openharmony-rs/ohos-sdk)
- Cross-compiles as a Linux target; the toolchain's `CMAKE_SYSTEM_NAME` is switched to Linux and `-D__OHOS__` is injected globally
- `--compile-no-warning-as-error` for musl/clang compatibility
- Patches: strip `.so` versioning, remove bf16/fp16 MLAS kernels and add SBGEMM no-op stubs, disable `pthread_setaffinity_np`, downgrade `make_unique_for_overwrite`/structured bindings to C++17, drop x86 fp16 kernel references
- The resulting library only depends on the OHOS system libraries `libc++_shared.so` and `libc.so`

## Credits

- [csukuangfj/onnxruntime-libs](https://github.com/csukuangfj/onnxruntime-libs) — primary reference for OHOS cross-compilation
- [ggg5111_admin/ohos_-onnx](https://gitee.com/ggg5111_admin/ohos_-onnx) — OHOS ORT build reference
- [openharmony-rs/ohos-sdk](https://github.com/openharmony-rs/ohos-sdk) — OpenHarmony SDK prebuilt packages

## License

MIT (same as ONNX Runtime).
