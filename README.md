# ohos-onnxruntime-libs

预编译的 [ONNX Runtime](https://github.com/microsoft/onnxruntime) 共享库，适用于 OpenHarmony (OHOS)。

## 背景

ONNX Runtime 官方不提供 OpenHarmony 预编译包。Flutter/ArkTS 应用手写识别（PaddleOCR）等场景需要 `libonnxruntime.so`，直接使用 Android NDK 编译的版本在 HarmonyOS 上会因 musl libc++ 不兼容而 `dlopen` 失败。本仓库通过 GitHub Actions 自动交叉编译，产出兼容 OHOS 的共享库。

## 支持架构

| 架构 | 说明 |
|------|------|
| `arm64-v8a` | 主流 ARM64 设备（华为 Mate/P 系列等） |
| `armeabi-v7a` | 32 位 ARM 设备（旧款电视/平板） |
| `x86_64` | 模拟器 / x86 开发板 |

## 快速使用

### 1. 手动触发编译

Actions → Run workflow → 指定 ORT 版本（默认 1.29.1）。

### 2. 下载产物

Actions → 对应 run → Artifacts 下载 `onnxruntime-ohos-{arch}-{version}.zip`。

### 3. 集成到项目

```bash
unzip onnxruntime-ohos-arm64-v8a-1.29.1.zip -d entry/libs/arm64-v8a/
```

### 4. 发布版本

```bash
git tag v1.29.1
git push origin v1.29.1
```

自动创建 GitHub Release 并上传三个架构的 .so。

## 技术细节

- 基于 [csukuangfj/onnxruntime-libs](https://github.com/csukuangfj/onnxruntime-libs) 的 OHOS 构建方案（patch 策略、cmake 参数、musl 兼容性处理均参考该项目）
- 工具链: OpenHarmony SDK（通过 [openharmony-rs/ohos-sdk](https://github.com/openharmony-rs/ohos-sdk) 下载）
- 编译标志: `--compile-no-warning-as-error` 解决 musl/clang 兼容性
- 自动 patch: bfloat16_t、pthread_setaffinity_np、fp16/bf16 MLAS 内核、SBGEMM stubs、structured bindings、make_unique_for_overwrite

## 致谢

- [csukuangfj/onnxruntime-libs](https://github.com/csukuangfj/onnxruntime-libs) — OHOS 交叉编译方案的主要参考
- [ggg5111_admin/ohos_-onnx](https://gitee.com/ggg5111_admin/ohos_-onnx) — OHOS ORT 构建参考
- [openharmony-rs/ohos-sdk](https://github.com/openharmony-rs/ohos-sdk) — OpenHarmony SDK 预编译包

## 许可证

MIT（同 ONNX Runtime）。
