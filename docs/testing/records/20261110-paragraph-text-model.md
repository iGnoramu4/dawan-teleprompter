# 段落化文本、开发音频入口与功能栏隐藏（0.22.0）

> 阶段：用户反馈 D（文本连贯 / 开发入口 / 功能栏显隐）｜ 构建：`0.22.0+2025` ｜ 日期：2026-11-10 ｜ 状态：可验收
> 目的：验证正文按段落连续显示、坐标语义迁移（断点/遥控/悬浮窗/外接屏/时间轴），以及开发音频入口与功能栏显隐。
> 关联：[20261109-reading-band-scroll-model.md](../../design/20261109-reading-band-scroll-model.md) §3.2.6、[20261106-reader-state-machine.md](../../design/20261106-reader-state-machine.md) §7/§9/§10/§11、[remote-protocol.md](../../api/remote-protocol.md) v3、[display-channel.md](../../api/display-channel.md)、[recording-timeline.md](../../api/recording-timeline.md) v2、[20261106-overlay-window.md](../../design/20261106-overlay-window.md)。

## 1. 需求对应

| 需求 | 实现位置 |
|---|---|
| 正文只按段落换行，段内连续、按宽度自然折行 | `packages/core_models/lib/src/script_model.dart`（`splitIntoSections`/`ScriptModel.fromSections`）；`LayoutSnapshot` 视觉行 |
| 语音对齐下沉到段内字符偏移 | `packages/core_alignment/lib/src/aligner.dart`（`AlignResult.anchorCharOffset`）、`normalizer.dart`；`reader_page.dart`（`_anchorChar`、`rowForChar`） |
| 旧断点不跳位 | `saveAnchor(..., model:)` + `anchor_model:<scriptId>`；`mapLegacyAnchorToParagraphs` |
| 遥控 v2 `anchorLine` 兼容 | `remote_protocol.dart` v3：`anchorOffset`/`anchorRow`/`rowProgress`/`lineUnit`/`anchorRowText` |
| 悬浮窗切片不越界 | `init` 新增 `rows`/`anchorRow`/`anchorOffset`，`overlay_app.dart` 优先 `rows` 并回退 `lines` |
| 时间轴锚点可回放/导出 | `core_recording` v2（`char`、`positionAt`）；`recording_export.dart` SRT 视觉行重映射 |
| 开发测试音频仅开发可见 | `apps/app/lib/shared/dev_flags.dart`；`reader_page.dart` 的 `if (devAudioEnabled)` |
| 功能栏可隐藏/唤出并持久化 | `reader_page.dart`（`_panelHidden`/`_buildPanelHandle`）；`reader_defaults_store.dart`（`reader_panel_hidden`） |

## 2. 实测通过

| 用例 ID | 内容 | 结果 | 证据 |
|---|---|---|---|
| PT-01 | 只按空行分段；段内句号/逗号/长文本不再切成语义行；无空行整篇为 1 段 | 实测通过 | `packages/core_models/test/script_model_test.dart` |
| PT-02 | 旧锚点映射：旧行 1 → 段落 0 + 字符 4，旧行 2 → 段落 1 + 字符 0；`fromSections` 段/行 1:1 | 实测通过 | `packages/core_models/test/script_model_test.dart` |
| PT-03 | 对齐结果携带段内字符偏移（整句对齐到第 10 字）；数字读法逐字偏移并夹取 | 实测通过 | `packages/core_alignment/test/alignment_test.dart` |
| PT-04 | 阅读页同一段内不按标点断行：长段落语义行 1 条、视觉行 > 1，跳转对话框只有 1 段 | 实测通过 | `apps/app/test/reader_page_interaction_test.dart`（「同段内不按标点断开」） |
| PT-05 | 断点写入 `anchor_model=2`；旧数据缺省 1；marker 全部映射到段落行 0 | 实测通过 | `packages/data_store/test/repository_test.dart` |
| PT-06 | 时间轴 v2：`char` 序列化、同段插值、跨段端点字符、v1 兼容、version 3 拒绝 | 实测通过 | `packages/core_recording/test/recording_timeline_test.dart` |
| PT-07 | 遥控 v3：新字段序列化/解析，v2 状态缺省回退 `sentence`/0，v3 上下行被接受，v4 被拒绝 | 实测通过 | `apps/app/test/remote_protocol_test.dart` |
| PT-08 | 遥控状态含 `lineUnit=paragraph`、`anchorRow=0`、`anchorOffset=0`、`rowCount=3`、`anchorRowText` | 实测通过 | `apps/app/test/reader_page_interaction_test.dart`（「局域网遥控」） |
| PT-09 | 悬浮窗 init 优先 `rows`/`anchorRow`，缺失回退 `lines`/`anchor` | 实测通过 | `apps/app/test/overlay_app_test.dart` |
| PT-10 | 功能栏隐藏后出现把手，持久化为 `1`；重新进入页面仍隐藏；点把手恢复并写回 `0` | 实测通过 | `apps/app/test/reader_page_interaction_test.dart`（「隐藏后保留把手可唤出并全局持久化」） |
| PT-11 | 全量回归：`flutter test` 182 项、`core_models` 31、`core_alignment` 41、`core_recording` 12、`core_scroll` 4、`data_store` 15、`core_reader_layout` 24 项全部通过 | 实测通过 | 第 4 节 |
| PT-12 | 四检：`dart format` 0 改动、`dart analyze --fatal-infos --fatal-warnings` 0 问题、`check_imports` OK | 实测通过 | 第 4 节 |
| PT-13 | 覆盖率：应用 81.7%（3093/3784）、`core_models` 79.9%、`core_alignment` 91.2%、`core_reader_layout` 93.8%、`core_recording` 96.6%、`core_scroll` 82.6%、`data_store` 78.1%，均 ≥ 70% | 实测通过 | `dart run tool/check_coverage.dart` |
| PT-14 | release APK（0.22.0，`app-release.apk`）安装到 API 36 arm64 模拟器：底部功能栏无「回放测试音频」入口（debug 包有） | 实测通过 | 模拟器截图 `/tmp/tp_reader2.png`；签名 Android Debug |
| PT-15 | 同一 release 包打开旧 13 段台本：段落内按宽度折行（「…工具，真 / 正的变化来自人 / 的习惯。」），句号/逗号处不强制换行；顶部显示视觉行 `44 / 44` | 实测通过 | 模拟器截图 `/tmp/tp_reader2.png` |
| PT-16 | release 包点「隐藏功能栏」→ 顶/底栏消失、右侧出现把手；`am force-stop` 后重进阅读页仍隐藏；点把手恢复功能栏 | 实测通过 | 模拟器截图 `tp_hidden.png` / `tp_restart.png` / `tp_shown.png` |

## 3. 仅接入未验证

| 项 | 原因 |
|---|---|
| 真机麦克风下的段内字符推进 | 单测覆盖字符偏移与视觉行映射；真实 ASR partial 在长段落中的推进节奏、回跳抑制需真机验收 |
| 旧遥控 v2 客户端与新主控 v3 互通 | 单测覆盖字段可选与回退；两台设备跨进程真实配对、以及旧 APK 的展示粒度未跑 |
| 外接屏视觉行的光学效果 | Dart 侧已改传视觉行，Kotlin 未改；HDMI/DP 实机上的换行宽度与阅读带位置未观察 |
| 旧 v1 录制在真机上的回放/导出 | 单测覆盖 v1 解码与迁移函数；未用历史真机录制文件验证 SRT 字幕切分 |
| 0.18–0.21 自动每行字数时期的旧断点 | 旧切行宽度未落库，只能按 40 字近似；可能偏移少量行（不越界），需真实旧库抽样确认 |
| 长段落 + 篇尾/循环 | 篇尾判定改为段落末字符，超长段落在真实语速下的静止判定需真机确认 |

## 4. 四检结果

```text
dart format --output=none --set-exit-if-changed lib test
  apps/app、core_models、core_alignment、core_recording、data_store → 0 changed
dart analyze --fatal-infos --fatal-warnings lib test
  apps/app、core_models、core_alignment、core_recording、data_store → No issues found!
dart run tool/check_imports.dart → OK
flutter test --coverage（apps/app） → 182 项全部通过
dart test（core_models / core_alignment / core_recording / core_scroll / data_store / core_reader_layout）
  → 31 / 41 / 12 / 4 / 15 / 24 项全部通过
dart run tool/check_coverage.dart
  app                  81.7% (3093/3784) OK
  core_models          79.9% (295/369)   OK
  core_alignment       91.2% (322/353)   OK
  core_reader_layout   93.8% (226/241)   OK
  core_recording       96.6% (113/117)   OK
  core_scroll          82.6% (57/69)     OK
  data_store           78.1% (429/549)   OK
```

## 5. 行为与兼容性

- 新台本/重新导入：空行分段；段内连续，仅按宽度折行。旧台本：每个历史存储分段（≤120 字）作为 1 个段落显示，原始空行边界不再恢复。
- 断点：`anchor_model` 缺失按旧句行迁移；迁移后写回 2。遥控 `anchorLine` 变为段落号，视觉行用 `anchorRow`；旧遥控端忽略新字段时粒度变粗但不越界。
- 悬浮窗优先视觉行 `rows`/`anchorRow`；旧浮窗回退段落 `lines`/`anchor`。外接屏 `lines`/`anchor` 语义改为视觉行，字段与 Kotlin 实现不变。
- 时间轴 v2 保存「段落 + 字符」；v1 在阅读页回放/导出前迁移，SRT 用视觉行输出，原始时间轴文件不改写。
- 功能栏隐藏为全局持久化（`reader_panel_hidden`）；右侧把手常驻可发现，锁定态隐藏把手但保留解锁角标。语音、录制、浮窗同步不依赖面板状态。
- 开发音频入口 release 默认隐藏，debug 或 `--dart-define=TP_DEV_AUDIO=true` 显示。

## 6. 构建产物

| 项 | 值 |
|---|---|
| 文件 | `teleprompter/apps/app/build/app/outputs/flutter-apk/teleprompter-0.22.0.apk`（同目录 `app-release.apk`） |
| 大小 | 210,224,889 字节（约 200.5 MiB） |
| SHA-256 | `4a414e5d2f6808800d36dc72ccfdcb0cd4fa14abc0aaae1ccecf0c70883c154d` |
| versionName / versionCode | `0.22.0` / `2025` |
| 签名 | Android Debug 证书（`CN=Android Debug`，SHA-256 `249f4471fc32f4568e2fe0227df4992e38383c9e88ccd2f84e64678659546183`） |
| 安装验证 | API 36 arm64 模拟器，`adb install -r` 成功；`SHA256SUMS` 已追加 `teleprompter-0.22.0.apk` |
