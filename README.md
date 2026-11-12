# 大皖提词器 · Dawan Teleprompter

> 听你读到哪里，就把画面推到哪里。语音识别、文本对齐、滚动与存储全部在本机完成。

[![Version](https://img.shields.io/badge/version-0.28.3-orange)](docs/releases/0.28.3.md)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.9-02569B?logo=flutter)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20macOS%20%7C%20Windows-4F5BD5)](#平台与构建)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
[![Status](https://img.shields.io/badge/status-internal%20testing-orange)](docs/releases/0.28.3.md)

## 一句话说清和普通提词器的差别

普通提词器按固定速度滚动，读快了要追、读慢了要等；**大皖提词器用本地流式语音识别判断你读到台本的哪一行，再把画面推到那一行**。停顿就停住，跳读能追上，口误不回跳，全程不需要联网、不需要账号。

- 识别：sherpa-onnx 流式 zipformer，16 kHz 单声道，本地推理。
- 对齐：按**读音**（无声调拼音音节）而不是逐字文本匹配，覆盖常见普通话混淆音。
- 滚动：固定阅读带 + 逐行吸附；手动拖动仍是连续像素滚动，不被语音目标拽回。
- 红线：单次自动前进 ≤ 3 行，任意 10 秒累计跳行 ≤ 3 行，30 分钟静音误触发 0。

## 项目定位与目标用户

面向需要“看着镜头/观众、不低头看稿”的口播与现场表达场景：

| 用户 | 典型场景 | 主要诉求 |
|---|---|---|
| 短视频 / 直播创作者 | 手机或电脑前口播，同时要看评论与素材 | 悬浮提词、手机遥控、录制与复盘 |
| 讲师 / 培训师 | 教室投影 + 讲台设备 | 外接显示、大字号高对比、稳定跟读 |
| 会议 / 演讲者 | 舞台、分光镜提词器 | 镜像、暗色、低延迟、抗回声 |
| 企业宣传 / 客服 | 固定话术录制 | 台本管理、Word/PDF 导入、时间轴导出 |

非目标：云同步、账号体系、云端识别、在线埋点、AI 改写、多人协作、直播推流。

## 功能清单

以当前 `0.28.3+2037` 的实际实现为准。

### 台本编辑与管理

- 新建空白台本、从剪贴板粘贴、从文件导入。
- 导入格式：`.txt`、`.md`、`.docx`、`.pdf`（仅文本层）、`.tps`（本应用台本包）。
- 导入预览与清洗：合并段内硬换行、去页码/页眉页脚、全角转半角、剥离 Markdown 标记。
- 自动保存；正文为整篇连续文本，按屏幕宽度自然折行。
- 行内标记：重点、停顿、换气、动作、时间码，可附备注。
- 台本管理：搜索标题或正文、按最近更新/创建时间/标题/字数排序、收藏、归档、删除到回收站（保留 30 天）。
- 导出单篇或全部 `.tps`（含标记与阅读预设）；导入 `.tps` 时按篇合并，不覆盖已有台本。
- 每日首次启动自动备份，保留最近 7 份；支持局域网互传（浏览器下载/上传 `.tps`）。

### 阅读页

- 固定阅读带：当前行默认停在视口约 34% 高度（可调 20%–60%），文字从带下方走到带内。
- 可调字号（24–160 px）、行距、字重、字距、左右边距、左对齐/居中。
- 两套舞台配色：舞台暗、高对比白；支持水平/垂直镜像与分光镜偏移校准。
- 点屏或点“开始”才滚动，避免误触；播放/暂停、上一句/下一句、速度（0.2–10 行/秒）。
- 锁定后屏蔽手势，仅遥控可用；阅读时保持屏幕常亮。
- 单栏功能栏可隐藏，右侧把手随时唤出；隐藏状态跨台本与重启保持。
- 每篇台本记住自己的字号、行距、速度、镜像等参数；新台本使用全局默认值。
- 中英文界面（ARB 国际化）。

### 语音跟随

- 完全本地离线识别，不上传音频、不依赖系统语音服务。
- 默认中文轻量模型 `zipformer-zh-14M-int8`（约 24 MB）；可在设置切换中英混说模型 `zipformer-bilingual-mixed`（约 209 MB）。
- 五档匹配宽松度（很严格 / 严格 / 标准 / 宽松 / 很宽松）；连续朗读时在档位内自适应放宽一档，退出后自动回到原档。
- 端到端延迟补偿开关；低置信时降速而不是乱跳；连续多次对不上时带 3 行上限重新锚定。
- 识别状态角标（准备中/收音中/静默/低置信/暂停）；对齐失败时识别文本与状态仍刷新，只冻结滚行。
- 麦克风权限被拒绝、模型缺失或引擎失败时自动退回手动滚动，不阻塞阅读。

### 遥控与多屏

- **局域网遥控**：阅读页开启后显示二维码与配对串；另一台设备用“遥控端”扫码或粘贴配对串连接（WebSocket，默认端口 7788）。
- 遥控端可播放/暂停、上一行/下一行、调速、镜像、锁定；协议层另定义滚动与跳转命令。
- **外接显示（Android）**：HDMI/DP 副屏独立输出纯稿件，跟随字号与镜像；拔出后自动停止。
- **悬浮提词（Android）**：系统级悬浮窗覆盖在相机等其他应用之上；可拖动、调宽度/透明度、切换 3/5 行、开始/暂停；未授权时保留应用内提词。

### 录制、复盘与导出

- 录制复用语音跟随的同一条麦克风采集流，不重复占用麦克风。
- 录制历史；按时间轴复盘，稿件随音频联动；支持 0.5×/1×/1.5×/2×。
- 导出 `.wav`、`.timeline.json`（10 Hz 采样、段落 + 字符坐标）与 `.srt` 字幕。

### 设置、备份与诊断

- 全局默认阅读参数、功能栏按钮、外观主题与强调色。
- 立即备份 / 导出最近备份；局域网互传。
- 导出诊断包（运行日志与阅读参数，不含台本正文）；“最近日志”可在应用内查看。
- 实验性 ASR 参数页仅在调试构建可见，正式版不显示。

## 语音跟随是怎么做的

详细版本见 [语音跟随原理](docs/overview.md#5-语音跟随原理)，这里只列关键链路：

```
麦克风 16 kHz / mono / PCM16
  → sherpa-onnx 流式识别（partial / final + 端点）
  → 归一化 → 拼音音节 → 模糊等价
  → 命中率预筛 → 窗口单调 DP 对齐
  → 整行读音覆盖度闸门 → 跟踪器 / 跳读预算
  → 视觉行坐标 → 固定阅读带滚动
```

- **按读音匹配**：中文一字一音节，英文术语整体一个 token；只比较无声调拼音，声调仅作小幅加分。
- **模糊等价**：`zh/ch/sh → z/c/s`、`n/l`、前后鼻音、`f/h`、`r/l`、`uang/uan`、`iang/ian`、`ing/in`、`eng/en`、`ang/an`、`iu/ou`，以及“声母相同 + 编辑距离 ≤ 1”的音节近似。
- **DP 对齐**：在有限窗口内做单调路径 DP，窗口以分句起点为锚、长度自适应（上限 600 音节），首行台本前缀免费跳过，避免长分句整体越出带宽后选择假路径。
- **整行覆盖度放行**：按行长分档要求 0.72–0.9 的读音覆盖率，并要求最远命中到达行内 60%、行内单调前进；行内字符偏移只用于坐标、进度与录制时间轴。
- **滚动**：语音跟随按整视觉行吸附（首行 `easeOutCubic` 约 500 ms，同一段追加行每行约 160 ms，单段位移 ≤ 1 行）；触控拖动/惯性直接改连续像素位置，松手不吸附、不被语音目标拽回。
- **三重跳读约束**：单次自动前进 ≤ 3 行；任意 10 秒内累计跳行 ≤ 3 行（逐行推进不计入）；失败重锚单次 ≤ 3 行且之后需 3 次正常命中才允许下一次重锚。

## 技术栈与仓库结构

- Flutter 3.47.9 / Dart 3.13.7；Riverpod 2；drift（SQLite）；Material 3。
- 语音：sherpa-onnx 2.x 流式 zipformer；拼音：`lpinyin`。
- 核心算法为纯 Dart 包，可脱离 Flutter 单测。

```
.
├── README.md / BUILDING.md / CHANGELOG.md
├── docs/                         # 规范、架构、设计、测试记录、发布说明
├── teleprompter/                 # Flutter 工程
│   ├── apps/app/                 # 应用壳（Android / macOS / Windows）
│   ├── packages/                 # 9 个本地包，publish_to: none
│   │   ├── core_models/          # 台本、分段、标记、预设等不可变模型
│   │   ├── core_alignment/       # 归一化、拼音模糊、窗口 DP、跳读闸门/预算
│   │   ├── core_reader_layout/   # 视觉行快照、固定阅读带、逐行吸附跟随
│   │   ├── core_scroll/          # 独立滚动规划（历史包，阅读页已改用 core_reader_layout）
│   │   ├── core_recording/       # 录制时间轴、插值、SRT 导出
│   │   ├── data_store/           # drift schema、仓储、迁移、断点
│   │   ├── design_system/        # Material 3 主题、令牌、阅读舞台调色板
│   │   ├── asr_kit/              # sherpa-onnx 封装、采集、模型解包、WAV 回放
│   │   └── overlay_bridge/       # 主引擎 ↔ 悬浮窗引擎 JSON 桥（仅 Android）
│   ├── eval/                     # 评测集：台本、标注、清单（音频由脚本生成，不入库）
│   ├── tool/                     # 检查、许可扫描、图标生成、模型清单、评测工具
│   └── assets/branding/          # 图标母版与三端图标产物
├── dist/                         # 本地发布物（被 .gitignore 排除）
└── models-eval/                  # 本地评测权重（被 .gitignore 排除）
```

依赖方向由 `tool/check_imports.dart` 强制：`core_*` 不得依赖 Flutter；`features/a` 不得 import `features/b`；`shared/` 不得反向依赖 `features/`；`packages/*` 不得依赖应用代码；`design_system` 不得依赖业务包。详见 [架构说明](docs/architecture/ARCHITECTURE.md)。

## 平台与构建

| 平台 | 当前状态 | 产物 |
|---|---|---|
| Android | **主力平台，已实现并装机验证**；`minSdk 24`、`targetSdk 36`，ABI `arm64-v8a` / `armeabi-v7a` / `x86_64` | APK（约 397 MB，内嵌两套模型与字体） |
| macOS | 构建脚本与界面已适配，**无可核对的构建成功与装机记录**；悬浮窗/外接屏/遥控为 Android 专属 | `.app` |
| Windows | 构建脚本与界面已适配，**无可核对的构建成功与装机记录**；复盘播放暂无实现 | `.exe` |
| iOS | 未构建，不在本期范围 | — |

### 环境

| 工具 | 版本 / 说明 |
|---|---|
| Flutter | 3.47.9 stable（见 `.fvmrc`） |
| Dart | 3.13.7（随 Flutter） |
| Android | JDK 17、Android SDK；一台 Android 7.0+ 设备（minSdk 24）或模拟器 |
| macOS | macOS 12+、Xcode 16+、CocoaPods |
| Windows | Windows 10/11、Visual Studio 2022（Desktop development with C++） |

> **Apple Silicon 必读**：请使用 arm64 版 Flutter SDK（本机为 `/Users/xatf/flutter-sdk/arm64/flutter/bin/flutter`）。x86_64 SDK 经 Rosetta 调起的 `xcrun` 无法加载 arm64-only CommandLineTools 的 `libxcrun`，会让 `flutter test` 的原生资源 hook 失败。
>
> **含空格/中文路径**：`flutter analyze` 在部分版本下会因 analysis server 的 `rootUri` 未转义而崩溃，静态检查请改用 `dart analyze`。

### 拉取依赖与运行

```bash
git clone https://github.com/iGnoramu4/dawan-teleprompter.git
cd dawan-teleprompter/teleprompter

flutter pub get
cd apps/app
flutter pub get
flutter devices
flutter run -d <device-id>
```

### 模型权重（重要）

模型权重**不进入 Git**，仓库只保留 `tool/models.lock.json` 清单与许可说明。默认中文模型必须按清单放入以下目录后才能使用语音跟随：

```
teleprompter/apps/app/assets/models/zipformer-zh-14M-int8/
```

可选的中英混说模型：

```
teleprompter/apps/app/assets/models/zipformer-bilingual-mixed/
```

下载来源、文件名、字节数与 SHA256 见 [models.lock.json](teleprompter/tool/models.lock.json)；放置后逐个校验：

```bash
shasum -a 256 teleprompter/apps/app/assets/models/*/*.onnx
```

未放置权重时应用仍可构建与启动，但语音跟随不可用；目录内的 `README.md` 占位保证 Flutter 能解析 assets。

### 构建

```bash
cd teleprompter/apps/app

# Android
flutter build apk --release

# macOS
flutter build macos --release

# Windows
flutter build windows --release
```

签名、公证、发布归档与回滚步骤见 [BUILDING.md](BUILDING.md) 与 [发布手册](docs/ops/release-runbook.md)。发布包需在格式化收敛后的干净源码上构建；构建后不得再改动手写 Dart，否则必须重打并重算 SHA256。

### 提交前检查

```bash
cd teleprompter

dart format --output=none --set-exit-if-changed .
cd apps/app && dart analyze --fatal-infos --fatal-warnings . && cd ../..
for p in packages/*; do (cd "$p" && dart analyze --fatal-infos --fatal-warnings .) || exit 1; done

dart run tool/check_imports.dart
cd apps/app && flutter test --coverage && cd ../..
dart run tool/check_coverage.dart --min 70 --core-min 85
dart run tool/license_scan.dart
```

CI 配置见 [.github/workflows/ci.yml](.github/workflows/ci.yml)，执行 format / analyze / check_imports / test / coverage / license_scan。

## 模型与字体等大资源

| 资源 | 体积 | 来源 | 许可 | 是否入库 |
|---|---|---|---|---|
| `zipformer-zh-14M-int8` | 约 24 MB（4 文件） | [csukuangfj / sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23](https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23) | Apache-2.0 | 否（清单入库） |
| `zipformer-bilingual-mixed` | 208,661,419 B（约 209 MB） | 上游 [bilingual-zh-en-2023-02-20](https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20)；encoder int8 + decoder/joiner fp32 | Apache-2.0 | 否（清单入库） |
| 思源黑体 / Noto Sans SC Black | 约 10 MB | Google Noto / 思源黑体同源 | SIL OFL 1.1 | 是（`assets/fonts/NotoSansSC-Black.ttf`） |

- **安装流程**：Android 发布包把模型随 APK 分发；首次开启语音跟随时，`asr_kit` 把所选模型从 assets 解包到应用私有目录，进度按真实写盘字节推进；失败会清理半成品并提示重试。**应用内不会联网下载权重**。
- 中英混说模型必须使用“encoder int8 + decoder/joiner fp32”的混合精度组合；全 int8 版本会系统性叠字，不可用。
- 模型许可与再分发边界见 [MODEL_LICENSE.md](MODEL_LICENSE.md)；第三方组件与字体许可见 [第三方许可清单](docs/legal/third-party-licenses.md)。
- 仓库中的 `teleprompter/assets/branding/proposals/` 为已否决的图标方案探索稿，**不进入公开仓库**（已在 `.gitignore` 排除）。

## 测试与评测

### 测试分层

| 层 | 范围 | 命令 |
|---|---|---|
| 单元测试 | `core_*` 纯 Dart 算法、数据模型、存储 | `dart test packages/core_alignment` 等 |
| 组件测试 | 页面、主题、空态/错误态 | `cd apps/app && flutter test` |
| 覆盖率门禁 | 整体 ≥ 70%，`core_*` ≥ 85% | `dart run tool/check_coverage.dart --min 70 --core-min 85` |
| 分层依赖 | 包边界与 feature 边界 | `dart run tool/check_imports.dart` |
| 许可扫描 | GPL/LGPL/MPL/未知许可拦截 | `dart run tool/license_scan.dart` |
| 评测集 | ASR + 对齐 + 滚动指标 | `cd tool/eval && dart run run_eval.dart ...` |

### 评测集与指标口径

评测集位于 `teleprompter/eval/`：台本与标注入库，音频由脚本生成、不入库。当前 **P0 为 10 段合成语音**（叙述、口头语、重复纠正、数字、中英术语/品牌、快读、长停顿、跳读、静音），用于回归红线，**不代表真人识别质量**。

常用命令：

```bash
cd teleprompter/tool/eval
dart run run_eval.dart \
  --model-dir ../../apps/app/assets/models/zipformer-zh-14M-int8 \
  --out ../../build/eval-report.json
```

指标口径：CER、首字延迟（P50/P95）、跟随延迟（P50/P95）、跟随命中率、静音误触发/分钟、抢行行数、单次最大跳行、任意 10 秒累计跳行、RTF、内存。真机取证使用 `tool/eval_device` 的 `MODE=record/replay`，可把麦克风采集的真人语音录成 WAV，再同时走实时流式管线与离线解码做对照。

当前红线实测（10 段合成语料）：误触发 0、单次最大跳行 0、任意 10 秒累计跳行 0。**真实麦克风语料仍为空**，因此不对识别质量下结论。

## 已知限制与未验证项

如实列出，不美化：

- **平台**：Android 是唯一完成装机验证的平台；macOS/Windows 只有构建脚本与界面适配，没有可核对的构建成功与装机记录；iOS 未构建。
- **签名**：现有 APK 使用 Android Debug 证书，仅供内测安装，不可用于应用商店分发；正式 keystore 尚未配置。
- **模型**：默认 14M 模型只支持中文，开箱不支持中英混说；切到 209 MB 双语模型后才有中英混说能力。0.28.0 起默认切回 14M，这是明确取舍。
- **真实语料**：评测集目前只有 10 段合成语音；TESTING.md 要求的 60 段真人集（男女、方言、中英混读、口误、噪声）尚未建立。合成语料只能验证时序与链路，不能证明真实识别质量。
- **真机长跑**：30 分钟真实环境音（舞台音箱、人群底噪）未验证；只在数字静音上验证了误触发 0。
- **外接显示 / 遥控**：参数透传与单测已覆盖，跨两台设备的真实配对、重连、扫码与外接屏光学位置尚未完成联调。
- **悬浮窗**：已可用，但窗口化手感与部分系统后台限制未完全验证。
- **已知跟随问题**：0.28.3 仍有少量尾句未到末行、个别快读片段 10 秒内推进 4 行（超过“累计跳行 ≤3”的口径，逐行推进不计入）；尾音补偿只在开发回放路径生效，release 实时麦克风路径不生效。
- **低内存机型**：未做基线；性能基准固定为骁龙 8 Elite / 12 GB 档中高端 Android，不为低端机做性能妥协。
- **CI**：markdownlint、链接检查、golden 与集成测试尚未接入；评测集未进入发布流水线。

完整清单与证据见 [交接文档](docs/ops/handover.md) 与 [0.28.3 发布说明](docs/releases/0.28.3.md)。

## 路线图

按当前优先级：

1. **建立真实录音语料**：≥10 段真人（男女、快读、口误/重复、跳读、舞台噪声），按 TESTING 扩到 60 段；没有真人语料，不调识别阈值。
2. **补齐 0.28.3 遗留**：尾句未到末行、个别片段 10 秒推进 4 行；先取证再决定“追赶速度 vs 红线”。
3. **真机联调**：外接屏与局域网遥控（两台设备）、悬浮窗手感、低存储解包失败路径。
4. **桌面端验证**：至少各跑一次 `flutter build macos --release` / `flutter build windows --release` 并记录；补 Windows 复盘播放。
5. **发布工程**：正式签名、商店合规、CI 接入 golden/集成测试与评测基线。

## 文档

- [项目详细说明](docs/overview.md)（功能、架构、原理、构建、资源、测试、限制、路线图）
- [文档索引](docs/README.md)
- [架构说明](docs/architecture/ARCHITECTURE.md) ｜ [ADR](docs/architecture/adr/README.md)
- [构建与运行](BUILDING.md) ｜ [发布手册](docs/ops/release-runbook.md)
- [用户手册](docs/help/user-guide.md) ｜ [常见问题](docs/help/faq.md)
- [测试规范](docs/testing/TESTING.md) ｜ [测试记录](docs/testing/records/)
- [隐私政策](docs/legal/privacy.md) ｜ [权限说明](docs/legal/permissions-statement.md) ｜ [第三方许可清单](docs/legal/third-party-licenses.md)
- [更新日志](teleprompter/CHANGELOG.md) ｜ [发布说明索引](docs/releases/README.md)

## 贡献

- [贡献指南](CONTRIBUTING.md)
- [行为准则](CODE_OF_CONDUCT.md)
- [安全策略](SECURITY.md)：安全漏洞请私下报告，不要公开 Issue。
- [商标政策](TRADEMARK.md)
- Issue / PR 模板位于 `.github/`。

提交 PR 前请跑通“提交前检查”的全部命令；涉及真机行为但未实测的改动，需要在测试记录中明确标注“仅接入未验证”。

## 许可与联系方式

- 代码：[Apache License 2.0](LICENSE)，版权人「吃不饱」。
- 运营定位：永久免费、作者不做商业发行。**“不商用”是维护者的运营选择，不是 Apache-2.0 之外的附加限制**；任何人均可依 Apache-2.0 使用、修改与再分发。
- 模型权重：适用各自上游许可（当前均为 Apache-2.0），不随代码许可自动分发，详见 [MODEL_LICENSE.md](MODEL_LICENSE.md)。
- 字体：Noto Sans SC，SIL Open Font License 1.1，全文见 `teleprompter/apps/app/assets/licenses/`。
- 联系方式：849779549@qq.com

## 致谢

- [Flutter](https://flutter.dev) / [Dart](https://dart.dev)
- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) 与 [k2-fsa](https://github.com/k2-fsa) 的 zipformer 模型
- [pdfrx](https://github.com/espresso3389/pdfrx)、[drift](https://drift.simonbinder.eu/)、[Riverpod](https://riverpod.dev/)
- Noto Sans SC / 思源黑体（SIL Open Font License 1.1）
