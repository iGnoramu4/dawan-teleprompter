# 阅读页固定阅读带（阶段 A）

> 阶段：阅读页显示与跟随重设计 阶段 A｜ 构建：`0.19.0+2022` ｜ 日期：2026-11-09 ｜ 状态：阶段 A 完成
> 目的：验证「固定阅读带 + 视觉行 + 一阶限速跟随 + 位置强调」的几何、收敛、迁移与设置持久化。
> 关联：[20261109-reading-band-scroll-model.md](../../design/20261109-reading-band-scroll-model.md)、[20261106-reader-state-machine.md](../../design/20261106-reader-state-machine.md) §9。

## 1. 需求对应

| 决策/需求 | 实现位置 |
|---|---|
| 固定阅读带替代行号高亮，位置强调按距离衰减 | `packages/core_reader_layout/lib/src/reading_band.dart`、`reader_page.dart`（`_buildReadingBandOverlay` / `_buildVisualRow`） |
| 保留经典高亮开关 | `reader_settings.dart`（`classicHighlight`）、`reader_settings_sheet.dart`、`reader_page.dart` |
| 视觉行几何与语义行映射 | `packages/core_reader_layout/lib/src/layout_snapshot.dart`、`reader_page.dart`（`_FlutterRowMeasurer`） |
| 一阶限速跟随替代二阶弹簧 | `packages/core_reader_layout/lib/src/reading_follower.dart`、`reader_page.dart`（`_onTick`） |
| 新建台本默认紧凑排版，旧预设保持原观感 | `reader_settings.dart`（`typographyModel` / `legacyLineHeightToPitch`） |
| 篇尾停止/循环字段 | `reader_settings.dart`（`endBehavior`）、设置面板（本阶段只持久化） |
| 镜像/分光镜与阅读带共存 | `reader_page.dart`（`_viewportMatrix` / `_positionOffset` / `ReadingBand.targetForRowWithMirror`） |

## 2. 实测通过

| 用例 ID | 内容 | 结果 | 证据 |
|---|---|---|---|
| RB-A-01 | 视觉行快照：单行/折行/空行/测量器空结果/最近行/顶部垫 | 实测通过 | `packages/core_reader_layout/test/core_reader_layout_test.dart`（6 项） |
| RB-A-02 | 阅读带：安全区比例夹取、最少上下行、镜像目标、极端安全区 | 实测通过 | 同上（5 项） |
| RB-A-03 | 位置强调：带内最强、按半径衰减、非法参数回 0 | 实测通过 | 同上（3 项） |
| RB-A-04 | 跟随器：240 ms 到 95%、无过冲、目标中途变化、回退去抖、>8 行落位淡入、>2.5 行追赶、冻结/拖拽/手动滚动 | 实测通过 | 同上（9 项） |
| RB-A-05 | 旧预设缺少 `typographyModel` 时按旧实际行距迁移（1.5 → 2.33），新模型往返不迁移 | 实测通过 | `apps/app/test/reader_settings_test.dart` |
| RB-A-06 | 默认 `lineHeight=1.55`、`classicHighlight=false`、`endBehavior=stop`、`readAheadRatio=0.34` | 实测通过 | 同上 |
| RB-A-07 | 经典高亮与篇尾行为往返持久化 | 实测通过 | 同上 |
| RB-A-08 | `textStyleHeight + 2×rowPadY + rowGap = lineHeight × fontSize` | 实测通过 | 同上 |
| RB-A-09 | 设置面板渲染经典高亮开关与篇尾行为分段控件 | 实测通过 | `apps/app/test/reader_settings_sheet_test.dart`（既有面板测试覆盖新增项渲染） |
| RB-A-10 | 阅读页既有交互（起始态、语音/回放、锁定、遥控、外接屏）在新布局下不回归 | 实测通过 | `flutter test`（171 项全部通过） |
| RB-A-11 | 四检：`dart format` 无变更、`dart analyze --fatal-infos --fatal-warnings` 0 问题、`check_imports` 通过、`flutter test --coverage` 全部通过 | 实测通过 | 见第 4 节 |
| RB-A-12 | 覆盖率：应用 82.7%（2931/3545）、`core_reader_layout` 93.8%（226/241），≥ 70% | 实测通过 | `dart run tool/check_coverage.dart --min 70` |

## 3. 仅接入未验证

| 项 | 原因 |
|---|---|
| 固定阅读带在真实语速下的观感、120/60 Hz 下的跟随与淡入手感 | 需要真机；单测只验证几何与收敛，没有覆盖物理屏幕与真实 ASR partial 抖动 |
| 1000 行台本在 5 Hz partial 下的帧耗时 | 已缓存测量、避免逐行重建 `TextPainter`，但全部视觉行仍参与 Widget 构建，需真机 Profile |
| 分光镜/外接屏的带位置与镜像目标 | 只做几何测试，未做光学实测 |
| 篇尾「停止/循环」运行行为 | 本阶段只持久化字段与 UI；运行逻辑在阶段 B 接入 |
| 重排时录音不断 | 本阶段沿用旧的 `_stopVoice` 路径；阶段 B 接入「录制不断 + 语音 300 ms 自动重启」 |
| 悬浮窗/外接屏复用阅读带 | 二者仍为旧坐标模型；阶段 C 接入 |
| 遥控端对 `layoutVersion` 递增的端到端表现 | 语义行号语义未变，协议不需改；跨进程联调仍需两台设备 |
| 旧预设 `lineHeight > 2.31` 的完全等价 | 新模型上限 2.5，旧高行距预设会被夹取；默认 1.5 已等价迁移，极端值需真机确认可接受 |

## 4. 四检结果

```text
dart format packages/core_reader_layout apps/app/lib/... apps/app/test/...
  → 无变更（复跑 0 文件改动）
dart analyze --fatal-infos --fatal-warnings
  packages/core_reader_layout → No issues found!
  apps/app lib test           → No issues found!
dart run tool/check_imports.dart → OK（core_* 未引入 Flutter/平台包）
flutter test --coverage（apps/app） → 171 项全部通过
dart run tool/check_coverage.dart --min 70
  [app] 82.7% (2931/3545 行) OK
  [core_reader_layout] 93.8% (226/241 行, 要求 >= 85%) OK
```

## 5. 行为说明

- 阅读带是屏幕空间静态覆盖层，不接收触摸；带顶默认位于安全区 34%，并按上下最少 1/2 行夹取，极端字号下也不会把带挤出屏。
- 位置强调按「视觉行号与锚点行号的距离」连续插值（半径 0.9 行）；开启「经典高亮」后恢复当前行全亮、下一行 0.72、其余压暗。
- 语音逐行模式仍由 `LineStepGate` 决定何时换行；换行后目标立即提交，不再叠加 60 ms 去抖，避免「先确认再等去抖」的双重延迟。回退目标保留去抖。
- 跳段/篇首/遥控跳转直接落位并 120 ms 淡入；拖拽松手吸附到最近视觉行。
- 旧预设迁移在 `ReaderSettings.fromJson` 内完成，写回时带上 `typographyModel: 2`，不会每次打开重复迁移。
