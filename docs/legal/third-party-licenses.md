# 第三方许可清单

本页汇总大皖提词器随包分发或构建时使用的第三方组件与许可。完整依赖树以各工作区的 `pubspec.lock` 为准；更新依赖后请重新运行扫描并同步本页。

```bash
cd teleprompter
dart run tool/license_scan.dart
```

扫描会读取仓库内全部 `pubspec.lock`，在 pub 缓存中定位许可文件，仅允许 Apache-2.0 / MIT / BSD-2-Clause / BSD-3-Clause / ISC / Zlib / Unlicense。GPL / LGPL / MPL / 未知许可会直接失败。仅 Linux 桌面运行时依赖（当前为 `dbus`）登记在 [`tool/license_scan_ignores.txt`](../../teleprompter/tool/license_scan_ignores.txt)，不随 Android / macOS / Windows 产物分发。

## 直接依赖

| 组件 | 版本 | 许可 | 用途 |
|---|---|---|---|
| Flutter / Dart SDK | 3.47.9 | BSD-3-Clause | UI 框架与运行时 |
| cupertino_icons | 1.0.9 | MIT | 图标字体 |
| flutter_riverpod | 2.6.1 | MIT | 状态管理 |
| file_picker | 13.3.2 | MIT | 文件选择 |
| path / path_provider | 1.9.1 / 2.1.6 | BSD-3-Clause | 路径与目录 |
| fast_gbk | 1.0.0 | BSD-3-Clause | GBK 文本解码 |
| archive | 4.6.0 | MIT | `.tps` 工程包解压 |
| xml | 7.1.0 | MIT | 工程包元数据 |
| pdfrx | 2.12.0 | MIT | PDF 渲染（内含 pdfium） |
| pdfium | 随 pdfrx | Apache-2.0 / BSD-3-Clause | PDF 渲染引擎 |
| shelf | 1.4.3 | BSD-3-Clause | 局域网遥控 HTTP 服务 |
| qr_flutter | 4.1.0 | BSD-3-Clause | 配对二维码 |
| flutter_overlay_window | 1.0.2 | MIT | Android 悬浮窗 |
| mobile_scanner | 7.5.0 | BSD-3-Clause | 扫码配对 |
| just_audio | 0.10.6 | MIT | 音频播放 |
| wakelock_plus | 1.8.2 | BSD-3-Clause | 阅读时保持常亮 |
| intl | 0.20.3 | BSD-3-Clause | 国际化 |
| flutter_lints | 6.0.0 | BSD-3-Clause | 静态检查规则（开发期） |

## 字体

| 组件 | 许可 | 分发文件 |
|---|---|---|
| Noto Sans SC | SIL Open Font License 1.1 | `teleprompter/apps/app/assets/fonts/NotoSansSC-Black.ttf`，全文见 `teleprompter/apps/app/assets/licenses/NotoSansSC-OFL.txt` |

## 语音识别与模型

| 组件 | 许可 | 说明 |
|---|---|---|
| sherpa-onnx | Apache-2.0 | 本地流式语音识别运行时 |
| zipformer-zh-14M-int8 | Apache-2.0 | 中文轻量模型，权重不随 Git 分发 |
| zipformer-bilingual-mixed | Apache-2.0 | 中英混说模型，权重不随 Git 分发 |

模型权重的来源、SHA256、再分发边界与随包/按需分发方式见 [MODEL_LICENSE.md](../../MODEL_LICENSE.md) 与 [`tool/models.lock.json`](../../teleprompter/tool/models.lock.json)。

## 平台与系统组件

- **Android**：AndroidX、Kotlin 标准库、Jetpack 组件（Apache-2.0）；系统字体与框架不随包分发。
- **macOS**：Apple 系统框架（系统许可）；Flutter engine（BSD-3-Clause）。
- **Windows**：Windows SDK / Visual C++ 运行库（Microsoft 许可）；Flutter engine（BSD-3-Clause）。

## 汇总

最近一次扫描（2026-11-10）：

| 许可 | 包数量 |
|---|---|
| Apache-2.0 | 15 |
| BSD-2-Clause | 2 |
| BSD-3-Clause | 127 |
| MIT | 31 |
| MIT / Apache-2.0 | 1 |
| 合计 | 177 |

扫描结果：**OK**，无 GPL / LGPL / MPL / 未知许可。

## 声明

- 本页不替代各组件的完整许可文本；Apache-2.0 组件的归属与声明汇总见仓库根目录 [NOTICE](../../NOTICE)。
- 如果你再分发本项目的二进制产物，请同时保留 [LICENSE](../../LICENSE)、[NOTICE](../../NOTICE) 与字体许可全文。
- 模型权重不适用代码的 Apache-2.0 许可，分发前请阅读 [MODEL_LICENSE.md](../../MODEL_LICENSE.md)。
