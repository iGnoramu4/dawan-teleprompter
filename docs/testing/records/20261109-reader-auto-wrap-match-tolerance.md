# 阅读页体验：自动每行字数 + 语音匹配档位

> 阶段：阅读页体验（先于 M3 剩余项）｜ 构建：`0.18.0+2021` ｜ 日期：2026-11-09 ｜ 状态：已完成
> 目的：验证「每行字数自动计算」与「语音匹配三档」的算法、持久化迁移、设置页交互与阅读页联动。
> 关联：[20261106-reader-state-machine.md](../../design/20261106-reader-state-machine.md) §6/§7。

## 1. 需求对应

| 需求 | 实现位置 |
|---|---|
| 按屏幕可用宽度、字号、字体算每行字数 | `packages/core_models/lib/src/line_fit.dart`（`LineFit`） |
| 字号/边距/旋转/窗口变化自动重排 | `apps/app/lib/features/reader/reader_page.dart`（`_prepareLayout` → `_maybeAutoReflow` → `_rebuildLines`） |
| 「每行字数」降级为只读展示 | `lib/shared/reader_settings/reader_settings_sheet.dart`（`autoLineCharsOf`） |
| 预设序列化与旧数据迁移 | `lib/shared/reader_settings/reader_settings.dart`（删除 `maxLineChars`，新增 `matchTolerance`） |
| 三档可调、持久化、阅读页生效、展示阈值 | `packages/core_alignment/lib/src/match_tolerance.dart`、`line_step_gate.dart`、`tracker.dart`、`aligner.dart`、`voice_follow.dart` |

## 2. 实测通过

| 用例 ID | 内容 | 结果 | 证据 |
|---|---|---|---|
| RW-01 | `LineFit.averageEm` 全角/半角/混排/空白/空文本估算 | 实测通过 | `packages/core_models/test/line_fit_test.dart`（5 项） |
| RW-02 | `LineFit.charsPerLine` 随宽度/字号/字距/平均字宽单调变化并夹取 `[6,80]` | 实测通过 | 同上（8 项，含 NaN/0 字号/超大宽度） |
| RW-03 | 三档参数单调、`of`/`parse` 容错、阈值摘要含具体数值 | 实测通过 | `packages/core_alignment/test/match_tolerance_test.dart` |
| RW-04 | 档位驱动 `LineStepGate`：标准档 0.56 立即推进、严格档需 0.72、宽松档 0.45 一次推进、宽松档允许 4 行跳跃 | 实测通过 | 同上 |
| RW-05 | 档位驱动 `AlignTracker`：`fromProfile` 取值、`applyProfile` 保留锚点、严格档拒绝标准档可接受的 0.25 候选 | 实测通过 | 同上 |
| RW-06 | 档位驱动 `AlignEngine`：`lookAheadLines`/`minScore` 可注入且影响预筛 | 实测通过 | 同上 |
| RW-07 | 旧预设 JSON 含 `maxLineChars` 时正常读入、该键不再写回、其他字段不丢 | 实测通过 | `apps/app/test/reader_settings_test.dart` |
| RW-08 | `matchTolerance` 往返持久化；未知字符串/非字符串回落标准档 | 实测通过 | 同上 |
| RW-09 | 设置面板「每行字数」为只读项（无 Slider），显示「当前约 18 字，随窗口自动调整」 | 实测通过 | `apps/app/test/reader_settings_sheet_test.dart` |
| RW-10 | 设置面板切换严格/宽松，`onChanged.matchTolerance` 同步且阈值摘要随之更新 | 实测通过 | 同上 |
| RW-11 | 默认 400×800 逻辑视口下 8 字台本自动断为 2 行（7 + 1），进度显示随之变化 | 实测通过 | `apps/app/test/reader_page_interaction_test.dart`（空分段用例） |
| RW-12 | 竖屏 400×800 → 横屏 800×400 总行数变少，转回竖屏恢复原行数 | 实测通过 | `apps/app/test/reader_page_interaction_test.dart`（屏幕旋转后按新宽度自动重排） |
| RW-13 | 四检：`dart format` 无变更、`dart analyze --fatal-infos --fatal-warnings` 0 问题、`check_imports` 通过、`flutter test --coverage` 全部通过 | 实测通过 | 见第 4 节 |
| RW-14 | 覆盖率 82.4%（2777/3372 行），≥ 70% 门槛 | 实测通过 | `dart run tool/check_coverage.dart --min 70` |

## 3. 仅接入未验证

| 项 | 原因 |
|---|---|
| 真机旋转/分屏/折叠屏展开时的重排观感 | 需要真机；自动化测试用逻辑视口尺寸变化验证了行数变化与位置恢复，但不覆盖物理旋转动画与折叠屏姿态 |
| 大字号 + 系统字体缩放 > 1.3 下的实际折行是否仍无溢出 | `LineFit` 用平均字宽 + 1.02 安全系数估算，实际字形宽度需真机确认 |
| 三档在真实噪声环境下的跟随手感与推荐档位 | 需要真机麦克风 + 实际演讲环境；当前仅用回放音频与单测验证阈值语义 |
| 录制进行中触发重排 | 现有实现经 `_stopVoice` 级联暂停录制，未做「录制中静默重排」，真机行为待验收 |
| 遥控端收到 `layoutVersion` 递增后丢弃行号缓存的端到端表现 | 单侧逻辑已在测试覆盖，跨进程联调需两台设备 |

## 4. 四检结果

```text
dart format packages/... apps/app/lib apps/app/test   → 无变更（复跑 0 文件改动）
dart analyze --fatal-infos --fatal-warnings
  packages/{core_models,core_alignment,core_scroll,core_recording,data_store,design_system,asr_kit} → No issues found!
  apps/app lib test                                                                    → No issues found!
dart run tool/check_imports.dart                      → OK（core_* 未引入 Flutter/平台包）
flutter test --coverage（apps/app）                    → 166 项全部通过
dart run tool/check_coverage.dart --min 70            → 82.4%（2777/3372 行）OK
```

## 5. 行为说明

- 自动断行保留「段 id + 段内偏移」恢复阅读位置；重排后 `_initialAnchorApplied = false`，下一帧按新行号重新定位。
- 语音跟随时发生重排会先 `_stopVoice()`，避免旧行号坐标系的跟踪结果落到新脚本上；重排后需要用户重新点麦克风。
- 切换匹配档位**不会**停麦或回跳：闸门按档位重建，跟踪器 `applyProfile` 热更新阈值，保留当前行与平滑状态。
- 标准档阈值与历史硬编码完全一致，旧用户升级后行为不变。
