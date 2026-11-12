# 阅读页固定阅读带（阶段 C）

> 阶段：阅读页显示与跟随重设计 阶段 C｜ 构建：`0.21.0+2024` ｜ 日期：2026-11-09 ｜ 状态：阶段 C 完成
> 目的：验证悬浮窗全稿模式下线后的窗口化跟随、外接屏 `bandRatio` 接入，以及遥控协议 v2 的向后兼容。
> 关联：[20261109-reading-band-scroll-model.md](../../design/20261109-reading-band-scroll-model.md) §3.9/§5.2/§5.3、[20261106-overlay-window.md](../../design/20261106-overlay-window.md)、[remote-protocol.md](../../api/remote-protocol.md)。

## 1. 需求对应

| 决策/需求 | 实现位置 |
|---|---|
| 悬浮窗下线全稿模式，改为自动跟随的窗口化模式 | `apps/app/lib/shared/reader_settings/overlay_settings.dart`、`apps/app/lib/features/reader/overlay/overlay_app.dart`、`reader_settings_sheet.dart` |
| 旧配置 `lineCount=0` 迁移为 5 行，不能打开就变样 | `OverlaySettings.normalized()`（`>=5` 或 `<=0` → 5，否则 3） |
| 外接屏复用阅读带位置 | `external_display.dart`（`bandRatio` 参数）、`ExternalDisplayController.kt`（`column.translationY`） |
| 遥控协议 v2 可选字段、兼容 v1 | `remote_protocol.dart`（`version=2`、`minSupportedVersion=1`）、`reader_page.dart`（`_remoteState()`）、`overlay_app.dart`（`init` 可选字段） |

## 2. 实测通过

| 用例 ID | 内容 | 结果 | 证据 |
|---|---|---|---|
| RB-C-01 | 悬浮窗行数只接受 3/5；`lineCount=0` 迁移为 5，`7` 归一到 5；5 行高度为 420 dp | 实测通过 | `apps/app/test/overlay_settings_test.dart`、`overlay_window_service_test.dart` |
| RB-C-02 | 旧全稿配置打开后按 5 行窗口渲染，自动跟随锚点，不再出现 `ListView` 全稿分支 | 实测通过 | `apps/app/test/overlay_app_test.dart` |
| RB-C-03 | 设置面板不再渲染「全稿」选项，仅保留 3 行 / 5 行 | 实测通过 | `apps/app/test/reader_settings_sheet_test.dart`（`find.text('全稿') findsNothing`） |
| RB-C-04 | 外接屏 `show` 透传 `bandRatio`；`update` 未传时默认 0.5 | 实测通过 | `apps/app/test/external_display_test.dart` |
| RB-C-05 | 遥控协议 v2：状态序列化包含 `rowHeight/rowCount/bandRatio/typographyModel`，`tryParse` 缺省回退；v1 上行仍被接受，v3 被拒绝 | 实测通过 | `apps/app/test/remote_protocol_test.dart` |
| RB-C-06 | 全量回归：`flutter test` 177 项、`core_alignment` 40 项、`core_reader_layout` 24 项全部通过 | 实测通过 | 第 4 节 |
| RB-C-07 | 四检：`dart format` 90 文件 0 改动、`dart analyze --fatal-infos --fatal-warnings` 0 问题、`check_imports` OK | 实测通过 | 第 4 节 |
| RB-C-08 | 覆盖率：应用 82.8%（3056/3689 行）、`core_alignment` 91.2%（320/351 行）、`core_reader_layout` 93.8%（226/241 行），均 ≥ 70% | 实测通过 | `dart run tool/check_coverage.dart --min 70` |

## 3. 仅接入未验证

| 项 | 原因 |
|---|---|
| 悬浮窗换窗滑动手感 | 当前实现为按锚点重算窗口切片后直接替换，未做 120–160 ms 滑动动画；需真机确认是否足够顺滑 |
| 旧 `lineCount=0` 用户在真机上的首次迁移体验 | 单测覆盖迁移逻辑，未覆盖升级安装后的真实数据库与浮窗重排 |
| 外接屏 `bandRatio` 的光学位置 | 只验证了 Dart 参数透传；Kotlin 平移公式未在 HDMI/DP 副屏实机观察，居中默认值也未做光学校准 |
| 遥控 v2 与旧版遥控端互通 | 单测覆盖 v1 上行兼容与字段可选；跨进程、两台设备的真实配对/重连未跑 |
| 遥控端读取 `rowHeight/rowCount/bandRatio/typographyModel` | 本仓库遥控端当前只消费既有字段；新字段已下发但尚无 UI 使用 |
| 悬浮窗在后台主引擎无帧时的窗口化表现 | 仍受 §6 已知限制约束；窗口化本身不解决后台定时器限制 |

## 4. 四检结果

```text
dart format apps/app/lib apps/app/test packages/core_alignment packages/core_reader_layout
  → Formatted 90 files (0 changed)
dart analyze --fatal-infos --fatal-warnings
  apps/app            → No issues found!
  core_alignment      → No issues found!
  core_reader_layout  → No issues found!
dart run tool/check_imports.dart → OK
flutter test --coverage（apps/app） → 177 项全部通过
dart test（core_alignment） → 40 项全部通过
dart test（core_reader_layout） → 24 项全部通过
dart run tool/check_coverage.dart --min 70
  [app] 82.8% (3056/3689 行) OK
  [core_alignment] 91.2% (320/351 行) OK
  [core_reader_layout] 93.8% (226/241 行) OK
```

## 5. 行为说明

- 悬浮窗只有 3 行 / 5 行两种窗口，窗口始终以锚点为中心并随锚点自动滚动；设置面板不再提供「全稿」。
- 旧配置读取时 `lineCount=0` 或越界值统一归一为 5 行、420 dp；写入后即为新值，不再重复迁移。
- 外接屏渲染保持 5 行文本块，`bandRatio` 仅决定文本块在副屏中的垂直位置；缺失时为 0.5（居中），原生夹取 0.2–0.8。
- 遥控协议 v2 只新增可选字段，`anchorLine` 仍为语义行；主控端继续接受 v1 遥控端上行消息，旧遥控端忽略新字段不影响控制。
- 篇尾暂停时 `playing=false`、`progress=1.0`；循环复位后 `anchorLine` 回到 0（阶段 B 行为，阶段 C 未改变）。
