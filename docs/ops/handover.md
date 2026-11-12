# 交接文档（0.28.3 · 2026-11-12）

> 读者设定：**没看过任何历史对话**，需要在 10 分钟内接手继续干活。
> 写法约定：只写能核对的事实；未验证的写「未验证」，不写「已修复」。

## 0. 十分钟接手路径

1. 读本文 §1–§4（约 6 分钟），知道东西在哪、红线是什么、提交前跑什么。
2. 跑一遍 §4 的门禁命令（约 3 分钟，缓存热时更快），确认环境没坏。
3. 看 §5 的未验证清单，别把「没测过」当成「没问题」；看 §7 挑优先级最高的活。

---

## 1. 项目现状

| 项 | 值 |
|---|---|
| 当前版本 | `0.28.3+2037`（`teleprompter/apps/app/pubspec.yaml`） |
| 包名 | `com.dawan.teleprompter`（`teleprompter/apps/app/android/gradle.properties` 的 `appApplicationId`，`build.gradle.kts` 的 `namespace` 与 `applicationId` 共用） |
| 应用名 | Android 启动器名「大皖提词器」（`AndroidManifest` 的 `android:label`）；macOS/Windows 的 `PRODUCT_NAME` / `BINARY_NAME` 仍是 `teleprompter`，桌面端未本地化 |
| release 产物 | `dist/teleprompter-0.28.3-android.apk`，396,865,491 B |
| SHA256 | `59f0e6be803c573ba6e133da4c2d6696c7eddb9a525e393cb60623f8c2fdd0e0`（0.28.3） |
| 签名 | APK Signature Scheme v2；Android Debug 证书 `C=US, O=Android, CN=Android Debug`（证书 SHA-256 `249f4471…9546183`）。**仅供测试安装，不可商店分发** |
| 构建标记 | 源码 `versionCode=2037`、`minSdk=24`、`targetSdk=36`、ABI `arm64-v8a` / `armeabi-v7a` / `x86_64`；0.28.3 release 本地构建 396,865,491 B（与 0.28.1 同长，`libapp.so` 三 ABI 尺寸不变、CRC 已变） |
| 校验台账 | `dist/SHA256SUMS`（0.24.0、0.25.0、0.26.0、0.27.2、0.28.1、0.28.3；`shasum -a 256 -c` 全过） |
| 最近装机 | 设备 `f37aa514`（Xiaomi 24091RPADC / Android 16）已从 `dist/teleprompter-0.28.1-android.apk` 覆盖安装到 `dist/teleprompter-0.28.3-android.apk`（`install -r`，未卸载），`versionName=0.28.3`、`versionCode=2037`，台本与断点保留（打开仍是 40/40 末行），冷启动无崩溃 |

> 注意：`dist/` 里**没有** 0.27.0 与 0.27.1 的 APK。0.27.0 的副本还在 `teleprompter/apps/app/build/app/outputs/flutter-apk/teleprompter-0.27.0.apk`（396,947,331 B，2026-11-11 09:57）；0.27.1 从未单独归档，已被 0.27.2 的 `app-release.apk` 覆盖。要回滚 0.27.1 只能从源码重打。

### 三端完成度

| 平台 | 状态 | 证据 / 边界 |
|---|---|---|
| Android | **已实现并装机验证（0.27.2）**：台本导入/编辑、整篇连续文本阅读页、固定阅读带 + 视觉行、语音跟随（sherpa-onnx 流式）、五档匹配、防跳红线、断点续读、录制/时间轴/复盘/SRT、系统悬浮窗、外接显示 `tps/display`、局域网遥控 v3、中文轻量/中英混合模型切换 | `docs/releases/0.27.0.md`、`docs/releases/0.27.2.md`、`docs/testing/records/` |
| macOS | **构建脚本与界面已适配，但没有可核对的构建成功记录，0.27.x 未构建、未装机实测**。悬浮窗、外接屏、遥控为 Android 专属，桌面未接入 | `BUILDING.md` 的 `flutter build macos --release` 命令；`docs/ops/release-runbook.md` |
| Windows | **构建脚本与界面已适配，但没有可核对的构建成功记录，0.27.x 未构建、未装机实测**；**复盘播放无官方实现**（会提示暂不支持，录音与导出不受影响） | `BUILDING.md`、`docs/help/faq.md` |
| iOS | 未构建 | `docs/help/faq.md` |

---

## 2. 代码结构

仓库根：`/Volumes/扩展 /提词器`（**注意「扩展」后面有一个空格**，所有命令都要加引号）。Dart 工程在 `teleprompter/`，产物台账与公开文档在仓库根的 `dist/`、`docs/`。

```
/Volumes/扩展 /提词器/
├── dist/                     # 发布产物 + SHA256SUMS
├── docs/                     # 唯一规范来源（本文件在 docs/ops/）
├── README.md / BUILDING.md / CHANGELOG.md
└── teleprompter/
    ├── apps/app/             # Flutter 应用（Android/macOS/Windows），唯一的可执行壳
    ├── packages/             # 9 个本地包，publish_to: none
    ├── eval/audio/           # 10 段评测音频（合成语料，见 §5）
    ├── tool/
    │   ├── check_imports.dart / check_coverage.dart / license_scan.dart
    │   ├── eval/             # 宿主评测：run_eval.dart + follow_sim/asr_runner/run_set
    │   └── eval_device/      # 真机评测壳：MODE=eval/record/replay，输出 record-report-*.json
    └── CHANGELOG.md          # 版本变更的唯一事实来源
```

### 包职责

| 包 | 职责 | 备注 |
|---|---|---|
| `core_models` | 台本模型（分段、句、行） | 纯 Dart |
| `core_alignment` | 归一化、拼音模糊匹配、窗口单调 DP、跳读闸门/预算 | 仅依赖 `lpinyin`，无 Flutter |
| `core_reader_layout` | 视觉行快照、固定阅读带、一阶跟随 | 纯 Dart |
| `core_scroll` | 临界阻尼弹簧滚动（ω=8、ζ=0.9）、停顿冻结、跳读追赶 | 纯 Dart |
| `core_recording` | 录制时间轴：10 Hz 采样、线性插值、SRT | 纯 Dart |
| `data_store` | drift schema、仓储、迁移、断点 | 依赖 `core_models`、`sqlite3` |
| `design_system` | 三端 Material 3 主题与阅读舞台调色板 | 只依赖 Flutter，不得依赖业务包 |
| `asr_kit` | sherpa-onnx 流式识别、麦克风采集、模型安装、WAV 回放 | Flutter 插件，独立 isolate 解码 |
| `overlay_bridge` | 主引擎 ↔ 悬浮窗引擎的 JSON 桥 | 仅 Android |

### 依赖方向（由 `tool/check_imports.dart` 强制，违规即红）

1. 所有 `core_*` 包（`core_models`、`core_alignment`、`core_reader_layout`、`core_recording`、`core_scroll`）**不得**依赖 Flutter 或 `dart:ui`；
2. `features/<a>` **不得** import `features/<b>`（跨 feature 必须下沉到 `packages/` 或 `apps/app/lib/shared/`）；
3. `lib/shared/` **不得**反向 import `features/`；
4. `packages/*` **不得** import 应用代码（`package:teleprompter/` 或跳出包 `lib` 的相对路径）；
5. `design_system` **不得** import `data_store` / `asr_kit` / `core_alignment` / `core_scroll` / `core_models`。

方向总览：`apps/app(features, shared)` → `packages/*`；`asr_kit`/`data_store` 是基础设施，只被 app 或其上层调用；`core_*` 保持纯 Dart，可被任意端复用。

> `docs/architecture/ARCHITECTURE.md` 里的包清单**已过时**（仍在提 `import_kit`、`remote_kit`、`diagnostics_kit`、`tp_platform`）。以本节和 `packages/` 实际目录为准。

---

## 3. 关键设计决策

### 3.1 模型选择

- **默认模型（0.28.0 起）**：`zipformer-zh-14M-int8`（中文轻量，约 14 MB 量级）。只支持中文，**开箱不再支持中英混说**，这是本轮明确接受的取舍。
- 可选 `bilingual-mixed`（中英混合 Zipformer），`tool/models.lock.json` 记录 **208,661,419 B（约 209 MB）**，encoder int8、decoder/joiner fp32；在设置里显式切换后下次语音跟随生效。
- 切换链路不只是一个常量：`ReaderSettings.asrModel` 默认值、缺键/未知值回落、设置面板选项顺序、`VoiceFollowSession` 的默认 `AsrModelSpec`、模型解包与加载路径都按所选模型走。旧预设缺 `asrModel` 时按默认中文轻量处理。
- 改模型前必须：先解决英文输出大小写/分词与归一化、`tokens.txt` sha256 回填、首次解包耗时、真机 RTF/PSS；数据不齐不换默认（`docs/design/20261110-bilingual-zipformer-plan.md`）。

### 3.2 读音匹配口径（0.27.0 起唯一口径，0.28.0 扩为五档）

- 宽松度是**五档**：`veryStrict / strict / standard / loose / veryLoose`，强弱顺序即枚举顺序；设置面板只显示档位名与一句用途说明，**不展示任何数值、阈值或算法术语**（`MatchProfile.thresholdSummary` 已删除）。旧三档名 `strict/standard/loose` 仍是合法值，其余旧值按 `standard` 处理。
- 单位是**音节**：中文一字一音节，英文术语整体一个 token；用无声调拼音比较，声调只作 0.1 的加分项。
- 模糊音：`zh/ch/sh → z/c/s`、`n/l`、前后鼻音、`f/h`、`r/l`、`uang/uan`、`iang/ian`、`ing/in`、`eng/en`、`ang/an`、`iu/ou`，另有「声母相同 + 编辑距离 ≤1」的音节级近似。
- 放行单位是**整行读音覆盖度**：按行长分档阈值 0.9 / 0.8 / 0.72 / 0.65，并要求最远命中 ≥ 行内 60%、行内单调前进。行内字符偏移只用于坐标/进度/录制时间轴，不参与放行。
- 不允许再引入「文字逐字匹配」开关：`phoneticMatch` / `matchMode` 读入忽略、写回不输出。

### 3.3 阅读带与跟随

- 固定阅读带：目标行停在视口 **35%** 高度（`ScrollPlanner.readAheadRatio=0.35`；用户设置 `readAheadRatio` 默认 **0.34**，可调 0.2–0.6）。
- 左右边距：`leftMargin` / `rightMargin` 两个独立设置（默认各 0.06，范围 0–0.4），舞台宽度 = `viewport * (1 - left - right)` 并封顶 980；封顶后剩余空间居中，左缘由 `ReaderSettings.stageLeftFor()` 计算。自动断行按实际可用宽度重算。
- 台本正文只有一整段连续文本（`rawText` 为唯一事实来源），没有段落结构；编辑、导入都只产生连续文本。
- 渲染层只做 `Transform.translate(0, -position)`，不触发文本重排；视觉行由 `LayoutSnapshot` 快照提供。
- 滚动位置是**连续像素量**，但两条驱动路径分开（0.28.2 起）：
  - **语音跟随**：目标是**整视觉行**（`LayoutSnapshot.rowForChar`），每跨一行由 `ReadingFollower.snapTo` 用 `easeOutCubic` 吸附到阅读带下划线；第一行 500 ms（平滑度 4–12 映射 550/500/450 ms/行），单段位移最多 1 行，段末速度为 0。行内字符推进不产生亚行位移。
  - **跨多行追赶**：同一次连续吸附中，第 2 行起每行 160 ms，避免 500 ms × 行数线性叠加。2 行 660 ms、3 行 820 ms；每行仍是独立 easeOutCubic + 逐行落位，不跳过中间行。取舍：单行事件保留完整 500 ms，追加行更短。
  - **触控**：`nudge` / `fling` 直接改连续像素位置，不做整行量化、松手不吸附；识别暂停或关闭时每帧 `freeze()`，正在进行的吸附立即取消，拖动/甩动不会被语音目标拽回。
- 语音与触控共用同一个 `ReadingFollower` 位置量；拖拽、惯性、显式跳转都会取消吸附。只有显式跳转或目标距离 >8 行才直接落位并做 120 ms 淡入。
- 冻结期间忽略 `snapTo`；拖拽结束仍只调用 `fling(velocity)`（450 ms 指数衰减，触边即停），不改回整行 `jumpTo`。
- 端到端延迟补偿估计仍按原口径写入 `voice/latency_compensation`，但不再以分数行前馈滚动目标：整行吸附下分数前馈会破坏「行落到下划线」。

### 3.4 跳读红线（不许放宽）

- 单次自动前进 **≤ 3 行**：`maxAutoLeapLines = 3`，在闸门、跟踪器、提前跨行三处 clamp，并有防回退测试。
- **任意 10 秒内跳行总和 ≤ 3 行**：`AutoAdvanceBudget`，在所有自动推进的唯一入口（阅读页 `_advanceTo`、评测 `FollowSimulator._advance`）统一夹一次；用尽后只允许 +1 逐行。**逐行推进不计入预算**，否则正常朗读会长期处于用尽态。
- 另外三道：失败重锚单次 ≤3 行、重锚后需 3 次正常命中才放行下一次、预筛接管需「置信 ≥0.5 且领先 ≥0.2」。
- 当前实测（10 段全量）：误触发 0、`maxSingleLeapLines=0`、`maxLeapLinesPer10s=0`、`totalLeapLines=0`。

### 3.5 对齐窗口锚点的教训（0.27.2 修复）

**这不是性能取舍，是缺陷。** 曾经的对齐窗口跟着「阅读位置」滑动，但 ASR 文本是「本分句累积」：

1. 文本前缀落在窗口之前，只能记成插入代价；
2. DP 带宽是 `|i-j| ≤ 40` 音节，分句超过 40 音节（约 8 s 快读）后真实路径直接落在带宽外；
3. DP 于是选「删掉台本前缀 + 把文本尾巴对到后面几行」的假路径；
4. 结果：锚点 8.1 s 起 1→2→3 连锁前跳、置信 0.19–0.31、滚行冻结，21.5 s 端点才追回（`p0-zh-fast-01` P50 2220 ms 的来源）。

现在的正确做法（`packages/core_alignment/lib/src/aligner.dart`）：

- 窗口起点取**分句起点**：端点重设；文本公共前缀 < max(3, 上次长度×0.5) 视为新分句；阅读位置远超「分句起点 + 文本长度」可解释范围时作废旧起点（覆盖手动跳行/断点续读）；
- DP 首行台本前缀**免费跳过**（`dp[i] = 0`）；
- 窗口自适应 `n = min(reachable, max(windowW, m + 2*band))`，上限 600 —— 带宽只约束分句内部局部错位。

改后同环境：zh_fast P50 2220→880 ms、P95 6454→1010、命中 80%→100%；10 段 97.4%→100%、P50 1032→925、P95 2854→1626。

### 3.6 延迟预算结论（0.27.2 实测，别再重复踩）

| 段 | 环境 | P50 | P95 |
|---|---|---|---|
| 采集分片 | 真机 | 80 ms | 80 ms |
| 音频线程排队 `backlogMs` | 真机 | 0 | 0 |
| 解码（每次 `decode`） | 宿主 | 0.0 ms | 3.2 ms |
| 对齐 DP（每次 partial） | 宿主 | 58 µs | 384 µs |
| 产生新行 → 重绘 | 真机 | 一帧内 | 7.07 ms（0.27.0 存档，见 §5） |
| **ASR 出字间隔（最大项）** | 宿主/真机同 | **320 ms** | **1280 ms** |

- 最大项是模型 chunk（320 ms）决定的出字节奏；解码 + DP + 重绘合计不足端到端 2%。**不要指望调线程/换小模型/增量对齐来降跟随延迟**——`--threads 2` 只让宿主 RTF 1.18%→0.99%，跟随 P50/P95 与 zh_fast 完全不变。
- 真机 `decodeMs` 1–20 ms/分片、RTF 8.6–9.3%；`decode` 762 次对 12329 个分片（`isReady` 门控，无重复喂入）；partial 不变时识别器本来就不产出。
- 对齐 DP 约 1 次/partial、984 格/次；`span<3` 已记 0 置信但 DP 仍跑（成本 µs 级）。
- 结论：跟随延迟的剩余部分主要是「这一行的第一个词被说出来所需的时间」，属于 ASR 出字节奏与朗读节奏，不是可优化的算力项。

---

## 4. 硬性质量门禁

### 4.1 必须用的 SDK

`/Users/xatf/flutter-sdk/arm64/flutter/bin/{flutter,dart}`（Flutter 3.47.9 / Dart 3.13.7，arm64）。

原因是 x86_64 SDK 经 Rosetta 调起的 `xcrun` 加载不了 arm64-only CommandLineTools 的 `libxcrun`，`flutter test` 会被原生资源 hook 阻断（`docs/testing/records/20261110-app-test-toolchain.md`）。`.fvmrc` 锁 `flutter: "3.47.9"`。

### 4.2 提交前必跑（`docs/README.md` §4）

```bash
cd teleprompter

# 1) 格式
/Users/xatf/flutter-sdk/arm64/flutter/bin/dart format --output=none --set-exit-if-changed .

# 2) 静态检查（必须 dart analyze；flutter analyze 在中文/空格路径下会崩）
cd apps/app && /Users/xatf/flutter-sdk/arm64/flutter/bin/dart analyze --fatal-infos --fatal-warnings . && cd ../..
for p in packages/*; do (cd "$p" && /Users/xatf/flutter-sdk/arm64/flutter/bin/dart analyze --fatal-infos --fatal-warnings .) || exit 1; done

# 3) 分层依赖
/Users/xatf/flutter-sdk/arm64/flutter/bin/dart run tool/check_imports.dart

# 4) 测试 + 覆盖率
cd apps/app && /Users/xatf/flutter-sdk/arm64/flutter/bin/flutter test --coverage && cd ../..
/Users/xatf/flutter-sdk/arm64/flutter/bin/dart run tool/check_coverage.dart --min 70 --core-min 85

# 5) 许可证（CI 会跑）
/Users/xatf/flutter-sdk/arm64/flutter/bin/dart run tool/license_scan.dart
```

- 覆盖率阈值：`apps/app` 整体 ≥ 60%、总阈值 `--min 70`、`core_*` ≥ 85%；本次 PR 新增/修改代码 ≥ 80%。当前整体 **79.0%**，未下调阈值。
- 当前基线（0.28.1）：`apps/app`、`core_alignment`、`core_reader_layout` 及其余本地包测试全过；`dart analyze` 应用与本地包无问题；`check_imports` OK；`license_scan` OK。
- `flutter analyze` 的坑：在本仓库（`/Volumes/扩展 /提词器`，含空格与中文）下部分 Flutter 版本直接崩溃。**统一用 `dart analyze`**，并在各包目录内分别执行。

### 4.3 评测命令（同环境对照的唯一口径）

```bash
cd teleprompter/tool/eval
/Users/xatf/flutter-sdk/arm64/flutter/bin/dart run run_eval.dart \
  --model-dir ../../apps/app/assets/models/zipformer-zh-14M-int8 \
  --out ../../build/eval-report.json \
  --threads 1
# 单段 + 事件轨迹
/Users/xatf/flutter-sdk/arm64/flutter/bin/dart run run_eval.dart \
  --model-dir ../../apps/app/assets/models/zipformer-zh-14M-int8 \
  --only p0-zh-fast-01 --dump --out ../../build/eval-zhfast.json
```

对照必须满足：同一台机器（arm64 宿主）、同一模型目录、同一语料、同一档位。报告里 `latencyBudget` 含解码/出字间隔/DP/跳行统计。

真机取证用 `tool/eval_device`（三种模式，见其 `lib/main.dart` 顶部注释）：

```bash
cd teleprompter/tool/eval_device
# 录一段真人麦克风 → 回放给生产引擎 + 离线全速解码对照
/Users/xatf/flutter-sdk/arm64/flutter/bin/flutter run -d f37aa514 --profile \
  --dart-define=MODE=record --dart-define=RECORD_SECONDS=60 \
  --dart-define=EVAL_DIR=/sdcard/Android/data/com.dawan.teleprompter.eval_device/files/eval \
  --dart-define=MODEL_DIR=/sdcard/Android/data/com.dawan.teleprompter.eval_device/files/models/zipformer-zh-14M-int8
```

输出 `record-report-<label>.json`：积压时间线、出字时间线、实时/离线文本对照。

### 4.4 打包与发布（`docs/ops/release-runbook.md`）

```bash
cd teleprompter/apps/app
/Users/xatf/flutter-sdk/arm64/flutter/bin/flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk "/Volumes/扩展 /提词器/dist/teleprompter-<ver>-android.apk"
cd "/Volumes/扩展 /提词器/dist" && shasum -a 256 teleprompter-<ver>-android.apk >> SHA256SUMS && shasum -a 256 -c SHA256SUMS
```

装机核对以 `dumpsys package` 为准：

```bash
adb -s f37aa514 install -r "dist/teleprompter-<ver>-android.apk"
adb -s f37aa514 shell dumpsys package com.dawan.teleprompter | grep -E "versionName|versionCode"
adb -s f37aa514 shell am force-stop com.dawan.teleprompter
adb -s f37aa514 shell monkey -p com.dawan.teleprompter -c android.intent.category.LAUNCHER 1
```

---

## 5. 已知缺陷与未验证项

> 全部按「未验证 / 部分验证」写，不要读成「已修复」。

| 项 | 状态 | 说明 |
|---|---|---|
| 0.28.0 视觉验收 | **已随 0.28.1 发布，待用户真机走查** | 单栏功能栏、五档宽松度、左右边距、无分段编辑器已通过 widget 测试；release 覆盖安装后首页正常，最终手感仍以用户实机确认为准。 |
| 0.28.1 滚动连续性 | **已发布，待用户手感确认** | 已确认并移除三处整行吸附（松手 `jumpTo(整行)`、语音目标 `rowForChar` 整行、`anchorRow` 进缓存键），改为分数行目标 + 单档限速 + 松手惯性。逐帧同口径对照：改前 `drag-before2.mp4` 松手处有 1 次 81 px 落位跳变，改后 `slow-drag-after.mp4` 最大 11 px、0 次吸附跳变。release 已覆盖安装到 f37aa514。 |
| 0.28.2 双路径滚动 | **已随 0.28.3 发布，待用户手感确认** | 语音跟随逐行 `easeOutCubic` 吸附：第一行 500 ms（平滑度 4–12 → 550/500/450），追加行 160 ms，单段 ≤1 行；触控保持连续像素自由滚动，暂停/关闭时冻结并立即取消吸附。真机 debug（f37aa514，平滑度 8.0）70 s 整段朗读 1/30 → 30/30 无跳过，单行吸附 492–508 ms；2 行 672 ms、3 行 826/834 ms、4 段 1005 ms。0.28.3 复测单行吸附 177 次中位 501 ms。帧：3607 帧 jank 4（0.11%），P95 build 1.27 / raster 5.61 / total 8.89 ms。 |
| 0.28.3 位置锁死修复 | **已发布，语速梯度已真机复测** | 对齐窗口改跟页面锚点；拖动/跳行同步 `tracker.forceLine(_anchor)`；`reset()` 清 `_line`；`span<6` 或 `conf<0.8` 只 +1 行。坏样本：暂停态 conf≤0.1 由 42/124 → 3/89；60 s 抢跑由 37.6 s 到 12 行 → 到 7–8 行，10 s 推进 6 → 3。**仍存在**：60 s / 45 s 尾句停在 11 行；45 s 档 9.1–19.0 s 推进 4 行（>3 行口径）；尾音补偿只在回放路径、release 内被 tree-shake。 |
| 真实录音语料 | **未验证（语料为空）** | `teleprompter/eval/audio` 的 10 段是合成语音；TESTING.md 要求的 60 段真人集（男女/方言/中英混读/口误/噪声）尚未建立。**所有识别质量结论都不能用合成语料下**。 |
| 真机 UI 帧数据 | **0.28.1 已重采（debug）** | 应用内 `FrameTiming` 插桩（`frame_summary`）：拖动 3610→3600 帧，janky 9→5（0.25%→0.14%），p95 total 6.59→6.60 ms；手动匀速 3151→3602 帧，janky 23→7（0.73%→0.19%），p95 total 8.92→9.55 ms；松手惯性 3610 帧，janky 8（0.22%），p95 total 8.99 ms；语音跟随 3600 帧，janky 12（0.33%），p95 total 6.41 ms。均在 16.7 ms 预算内。`dumpsys gfxinfo` 在 Flutter/Impeller 上仍返回 `Total frames rendered: 0`，不能作为数据源。 |
| 外接显示（`tps/display`） | **仅接入未验证** | 只验证了 Dart 参数透传；Kotlin 平移公式、`bandRatio` 光学位置未在 HDMI/DP 副屏实机观察。 |
| 局域网遥控 v3 | **仅接入未验证** | 单测覆盖 v1 上行兼容与字段可选；跨两台设备的真实配对/重连/扫码未联调；遥控端尚未消费新字段。 |
| 悬浮窗 | **部分验证** | 窗口化按锚点重算切片直接替换，无 120–160 ms 滑动动画，手感未真机确认；后台主引擎无帧时的表现受系统定时器限制。 |
| 解包失败回滚 | **部分验证** | debug 同签名包注入失败已实测：失败态 + 重试 + 半成品目录清理 + 重试后文件字节一致。release 包不可 `run-as`，未在 release 上复现；`cleaned=false` 分支与低存储（<210 MB）场景未验证（`docs/testing/records/20261110-first-install-progress.md`）。 |
| 30 分钟真实环境音 | **未验证** | 只跑过数字静音（误触发 0、锚点 0 行）；舞台音箱/人群底噪长跑未做。 |
| 首字跟随延迟 | **未专项复测** | TESTING §5.2 目标 ≤500 ms（P95 ≤800）；本轮报告的是**行级** `followLatency`（P50 925 / P95 1626），口径不同，不可直接对照。 |
| 低内存机型 | **未验证** | 只在 f37aa514（SM8635）上测过；PSS/RTF 在低端机未知。 |
| 模型切换证据 | **未验证** | 目录级双模型共存有单测；0.28.0 默认 14M 的真机首次解包耗时、切到 209 MB 中英混合后的加载未实测。 |

---

## 6. 踩过的坑

1. **打包后又改源码。** 曾出现 APK 与仓库源码不一致、事后重打才发现。现在的规矩：`dart format --set-exit-if-changed` 0 变更 → 构建 → **构建后不再触碰任何手写 Dart**；若必须改，重打并重算 SHA256、更新 `dist/SHA256SUMS` 与发布说明。核对手段：`strings app.so | grep _commonPrefix`（新符号在不在包里）、`aapt2 dump badging`（版本/包名）、`dumpsys package`（装机版本）。
2. **指标口径不一致导致结论错误。** 早期报的 baseline 87.2% / P95 5734 ms 来自 x64 旧环境，与 arm64 同语料数字不可比，已作废；`build/eval-027-legacy.json` 的 100% / 877 / 1626 也因跟随链路不同（legacy 在 605/801 ms 切行）不能当基线。**只有同宿主架构 + 同模型 + 同语料 + 同档位的前后对照才算数。**
3. **把缺陷误判成「性能取舍」。** 0.27.1 的 zh_fast 2220 ms 一度被归因为「防跳读牺牲的延迟 / 模型出字节奏」，实际是对齐窗口起点错了。教训：先做四段端到端预算（采集/解码/DP/重绘）+ 单段轨迹取证，再谈参数；不要用「优化参数」去掩盖定位错误。
4. **`dumpsys gfxinfo` 在 Flutter/Impeller 上无帧统计**（`Total frames rendered: 0`）。UI 帧数据用应用内 `SchedulerBinding.addTimingsCallback` 汇总，退出阅读页时写 `reader/frame_summary`（在设置页「最近日志」可看）。
5. **系统设置页会缓存旧版本号。** 装机后「应用信息」曾显示 0.27.0，force-stop `com.android.settings` 再打开才变 0.27.2。版本号以 `dumpsys package` 为准。
6. **`dist/` 历史包不全。** 只有 0.24.0/0.25.0/0.26.0/0.27.2；0.27.1 的构建产物已被 0.27.2 的 `app-release.apk` 覆盖，只剩 0.27.0 的副本在 build 目录。要回滚这两版只能从源码重打。
7. **`BUILDING.md` 旧规则自相矛盾。** 原文写「发布包必须在未执行过 `dart format` 的干净源码上构建」，与本项目现行「格式化收敛后再构建」冲突，已按实际做法修正。
8. **release 包不可 `run-as`。** 真机日志在应用私有目录，`adb` 取不到；失败注入、文件级核对只能用同签名 debug 包，结论只能推断到 release，不能声称 release 已复现。
9. **模型不能「偷偷换」。** 换回 14M 会丢中英混说；`tool/models.lock.json` 锁了字节数与 sha256，改模型必须同步改锁文件、更新包体记录、并在 PR 写明取舍。
10. **只挂在 debug 入口的修复会被 release tree-shake 掉。** 0.28.3 的尾音补偿只被「回放测试音频」（debug 按钮）调用，release 包 `libapp.so` 里查不到 `finishWithTail`，等于对装机用户无效。教训：修复要沿**用户可达路径**核对符号，不能只看源码；`strings libapp.so | grep <新符号>` 必须能在包内命中。
11. **`flutter analyze` 在含空格的工作区路径下会崩**（analysis server 的 `rootUri` 未转义，`file:///Volumes/扩展 /提词器/…`），报 `Unexpected character`。本机改用 `flutter test` 做编译与行为验证，并在报告里注明这是环境问题而非代码告警。
12. **引擎 `_line` 与页面锚点是两个量。** 手动滚动只改 `_anchor`、闸门与对齐窗口却看 `tracker.line`，两边一分叉就永久锁死（0.28.3 的根因）。任何「用户改了位置」的入口都必须同步跟踪器，新增入口时先问一句「跟 sync 了吗」。

---

## 7. 下一步待办（按优先级）

**P0 — 质量结论的前置条件**

1. 建真实录音语料：≥10 段真人（男女、快读、口误/重复、跳读、舞台噪声），60–120 s/段，人工标注脚本 token 区间；按 TESTING §5 扩到 60 段。可用 `tool/eval_device` 的 `MODE=record` 在真机录、`MODE=replay` 复放（命令见 §4.3）。没有真人语料，任何识别质量/阈值结论都不成立。

**P1 — 补齐本版缺口**

2. 0.28.3 遗留：60 s / 45 s 档尾句停在 11 行（识别器不产出「谢谢大家」）；45 s 档 9.1–19.0 s 推进 4 行（>「10 s 跳行 ≤3」口径）。前者属 ASR 侧，后者需再权衡「追赶速度 vs 红线」，两者都建议等真人语料。
3. 尾音补偿目前只在回放路径且被 release tree-shake；若要让麦克风实时路径也补尾音，必须先设计「非假 final」的端点后处理，并证明不抬误触发。
4. 在 0.27.2 上重采真机 UI 帧数据（`reader/frame_summary`）并补进 `docs/releases/0.27.2.md`。
5. 首字跟随延迟专项复测（口径按 TESTING §5.2：说话起始 → 首次滚动，≤500 ms / P95 ≤800 ms）。
6. 外接屏与遥控真机联调（两台设备）：`bandRatio` 光学位置、配对/重连/扫码、遥控端消费新字段。
7. 悬浮窗窗口化手感与 `lineCount=0` 老用户升级迁移真机验证。

**P2 — 性能与健壮性**

8. 解包失败在 release 等价路径复现（低存储、`cleaned=false` 文案）；低内存机型 PSS/RTF 基线。
9. 增量对齐/预筛优化：当前 DP 58 µs/partial，收益极小，**必须先有真人语料**证明不损质量再动。
10. 解码侧维持现状（单线程、不换模型）；若未来要调线程数，用同环境 A/B 证明跟随收益，而不是只看 RTF。

**P3 — 工程与平台**

11. macOS/Windows 本轮未构建验证：至少各跑一次 `flutter build macos --release` / `flutter build windows --release` 并记录。
12. Windows 复盘播放缺失（无官方播放器实现），需要明确产品口径或补实现。
13. CI 尚未接入 markdownlint/链接检查/golden/集成测试；评测集与基线文件（`eval/baseline.json`）需要固化到发布流程。
