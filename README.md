# ohos-onnxruntime-libs

预编译的 [ONNX Runtime](https://github.com/microsoft/onnxruntime) 共享库，适用于 OpenHarmony (OHOS)，一次构建同时产出 `arm64-v8a`、`armeabi-v7a`、`x86_64` 三个架构。

## 背景

ONNX Runtime 官方不提供 OpenHarmony 预编译包。Flutter/ArkTS 应用手写识别（PaddleOCR）等场景需要 `libonnxruntime.so`，直接使用 Android NDK 编译的版本在 HarmonyOS 上会因 musl libc++ 不兼容而 `dlopen` 失败。本仓库通过 GitHub Actions 自动交叉编译，产出兼容 OHOS 的共享库。

## 支持架构

| 架构 | 交叉编译器（OHOS SDK 内置） | 说明 |
|------|------|------|
| `arm64-v8a` | `aarch64-unknown-linux-ohos-clang` | 主流 ARM64 设备（华为 Mate/P 系列等） |
| `armeabi-v7a` | `armv7-unknown-linux-ohos-clang` | 32 位 ARM 设备（旧款电视/平板） |
| `x86_64` | `x86_64-unknown-linux-ohos-clang` | 模拟器 / x86 开发板 |

> 注意：32 位 ARM 的编译器前缀是 `armv7-`（不是 `armv7a-`），三个架构的编译器均由同一份 OHOS Native SDK 提供。

## 快速使用

### 1. 手动触发编译

Actions → "Build ONNX Runtime for OpenHarmony" → Run workflow → 指定 ORT 版本（默认 1.29.1）。三个架构并行编译，互不影响（`fail-fast: false`）。

### 2. 下载产物

Actions → 对应 run → Artifacts，每个架构一个压缩包：`onnxruntime-ohos-{arch}-{version}`，解压后为：

```
libonnxruntime.so            # 已设置 SONAME=libonnxruntime.so，无 .so.1 版本后缀
include/onnxruntime_c_api.h  # 公共 C API 头文件
```

### 3. 集成到项目

```bash
unzip onnxruntime-ohos-arm64-v8a-1.29.1.zip -d entry/libs/arm64-v8a/
```

### 4. 发布版本

推送 `vX.Y.Z` 标签即自动构建三个架构并汇总到同一个 GitHub Release：

```bash
git tag v1.29.1
git push origin v1.29.1
```

### 5. 上游自动同步

`Sync upstream ORT releases` 工作流每 6 小时检查一次 `microsoft/onnxruntime` 的最新稳定 Release；若发现本仓库尚未发布的新版本，会自动以该版本触发三架构构建并创建对应 Release，无需人工干预。也可在 Actions 页面手动 Run workflow 立即检查一次。

## 仓库结构

```
.github/workflows/ci.yml             # 三架构构建 + 汇总发布（同时是可复用工作流）
.github/workflows/sync-upstream.yml  # 定时检测上游新版本并触发构建
scripts/patch_ohos.sh                # ORT 源码的 OHOS 兼容补丁（幂等）
scripts/build_ohos.sh                # cmake 配置 + make 交叉编译
scripts/collect_ohos.sh              # 收集 .so、修正 SONAME、校验 ELF 架构与依赖
```

## 技术细节

- 参考 [csukuangfj/onnxruntime-libs](https://github.com/csukuangfj/onnxruntime-libs) 的 OHOS 构建方案（patch 策略、cmake 参数、musl 兼容性处理）
- 工具链：OpenHarmony Native SDK 5.0.0.71（clang 15.0.4），来自 [openharmony-rs/ohos-sdk](https://github.com/openharmony-rs/ohos-sdk)
- 以 Linux 目标交叉编译：toolchain 内 `CMAKE_SYSTEM_NAME` 改为 Linux，并全局注入 `-D__OHOS__`
- `--compile-no-warning-as-error` 规避 musl/clang 下的告警即错误
- 自动补丁：去除 `.so` 版本号、bf16/fp16 MLAS 内核裁剪与 SBGEMM 空实现、`pthread_setaffinity_np` 屏蔽、`make_unique_for_overwrite`/结构化绑定的 C++17 降级、x86 fp16 内核引用清理
- 产物仅依赖 OHOS 系统自带的 `libc++_shared.so` 与 `libc.so`

## 本地复现（Linux）

```bash
# 1. 准备 OHOS Native SDK（解压到 command-line-tools/sdk/default/openharmony/native）
# 2. 拉取对应版本 ORT 源码（含子模块）到 onnxruntime/
git clone --depth 1 --branch v1.29.1 --recursive https://github.com/microsoft/onnxruntime.git

bash scripts/patch_ohos.sh arm64-v8a "$PWD/onnxruntime" "$PWD/command-line-tools/sdk/default/openharmony/native"
bash scripts/build_ohos.sh arm64-v8a aarch64 "-O3 -Wno-unused-parameter -Wno-unused-command-line-argument" \
  "$PWD/onnxruntime" "$PWD/command-line-tools/sdk/default/openharmony/native" "$PWD/fc-cache" 2
bash scripts/collect_ohos.sh arm64-v8a 1.29.1 "$PWD/onnxruntime" "$PWD/output"
```

把 `arm64-v8a/aarch64` 换成 `armeabi-v7a/armv7`（额外加 `-mfloat-abi=softfp -mfpu=neon`）或 `x86_64/x86_64` 即可构建其余架构。

## 致谢

- [csukuangfj/onnxruntime-libs](https://github.com/csukuangfj/onnxruntime-libs) — OHOS 交叉编译方案的主要参考
- [ggg5111_admin/ohos_-onnx](https://gitee.com/ggg5111_admin/ohos_-onnx) — OHOS ORT 构建参考
- [openharmony-rs/ohos-sdk](https://github.com/openharmony-rs/ohos-sdk) — OpenHarmony SDK 预编译包

## 许可证

MIT（同 ONNX Runtime）。
