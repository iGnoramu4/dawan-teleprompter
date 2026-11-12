# 阅读页固定阅读带（阶段 B）

> 阶段：阅读页显示与跟随重设计 阶段 B｜ 构建：`0.20.0+2023` ｜ 日期：2026-11-09 ｜ 状态：阶段 B 完成
> 目的：验证篇尾停止/循环、early arm 提前跨行、自动重排不中断语音（热替换对齐对象），并为阶段 C「真正热换索引、不停麦」留好接口。
> 关联：[20261109-reading-band-scroll-model.md](../../design/20261109-reading-band-scroll-model.md)、[20261106-reader-state-machine.md](../../design/20261106-reader-state-machine.md) §10、[阶段 A 记录](20261109-reading-band-stage-a.md)。

## 1. 需求对应

| 决策/需求 | 实现位置 |
|---|---|
| 篇尾默认停止、可选循环 | `reader_page.dart`（`_handleFinished` / `_restartLoop` / `_endRestMs`）、`reader_settings.dart`（`endBehavior`） |
| 篇尾文案 | `app_zh.arb` / `app_en.arb`（`readerFinished`）、`reader_page.dart`（语音状态条与手动模式提示） |
| early arm 提前跨行 | `packages/core_alignment/lib/src/early_arm.dart`、`reader_page.dart`（`_onVoiceUpdate`） |
| 重排不中断录音、语音链路 300 ms 内自动重启 | `reader_page.dart`（`_maybeAutoReflow` / `_rebuildLines(keepVoice)`）、`voice_follow.dart`（`restartWith`） |
| 阶段 C 接口 | `VoiceFollowSession.restartWith` 作为唯一替换入口；阶段 C 只改其内部实现 |
| 遥控/悬浮窗状态同步 | 既有 `playing = _started && !_paused` 与 `layoutVersion` 递增逻辑，无需改协议 |

## 2. 实测通过

| 用例 ID | 内容 | 结果 | 证据 |
|---|---|---|---|
| RB-B-01 | early arm：严格档关闭、已读比例不足不触发、连续 2 次才跨行、final 立即跨行、前缀不匹配不触发、末行不触发、`replaceIndex` 清空计数 | 实测通过 | `packages/core_alignment/test/early_arm_test.dart`（7 项） |
| RB-B-02 | `restartWith` 直接替换对齐索引与跟踪器，耗时 < 300 ms | 实测通过 | `apps/app/test/voice_follow_test.dart` |
| RB-B-03 | 默认篇尾停止：手动滚动到末行后暂停、显示「已到篇尾」、行号停在末行 | 实测通过 | `apps/app/test/reader_page_interaction_test.dart`「篇尾行为」 |
| RB-B-04 | 循环模式：篇尾暂停后 1.2 s 回到篇首并恢复运行（暂停图标、行号回到 1/N） | 实测通过 | 同上 |
| RB-B-05 | 设置面板「篇尾行为」持久化与默认值 | 实测通过 | `apps/app/test/reader_settings_test.dart`（阶段 A 已覆盖） |
| RB-B-06 | 阅读页既有交互（起始态、语音/回放、锁定、遥控、外接屏、设置面板）不回归 | 实测通过 | `flutter test` 174 项全部通过 |
| RB-B-07 | 四检：`dart format` 无变更、`dart analyze --fatal-infos --fatal-warnings` 0 问题、`check_imports` 通过、测试与覆盖率通过 | 实测通过 | 见第 4 节 |
| RB-B-08 | 覆盖率：应用 82.8%（3038/3671）、`core_alignment` 91.2%（320/351）、`core_reader_layout` 93.8%（226/241），均 ≥ 70%（核心包 ≥ 85%） | 实测通过 | `dart run tool/check_coverage.dart` |

## 3. 仅接入未验证

| 项 | 原因 |
|---|---|
| 真机麦克风下自动重排时录音分片连续、无掉字 | 测试环境没有真实 ASR 流；已通过「不调用 `stop` / 不取消音频订阅 / 只替换纯 Dart 对象」保证设计意图，仍需真机录一段音频并在重排时回放确认 |
| 300 ms 自动重启在真实设备上的端到端时延 | 单测只测 `restartWith` 的纯 Dart 耗时；真实耗时包含 ASR 线程调度与帧预算，需真机日志 `voice/align_restart` |
| early arm 在真实语速/噪声下的误触发率 | 只有确定性单元测试；「已读 55% + 前缀全命中 + 连续 2 次」的参数需真机标定 |
| 篇尾判定在语音模式下的手感（0.6 s 静止） | 手动模式已组件测试；语音模式依赖 `ReadingFollower.atRest`，需真机确认不会因 partial 抖动提前停顿 |
| 循环复位与录音时间轴/遥控端的联动 | 循环不重建录制会话，时间轴仍连续；跨设备联调未做 |
| 真正增量热换索引（阶段 C） | 本轮只保证录音不断；替换瞬间的 partial 对齐结果会由新 `AlignEngine` 重新开始，阶段 C 再消除这一次丢失 |
| 悬浮窗「全稿模式」下线（阶段 C） | 本轮未改动；悬浮窗已同步篇尾暂停状态 |

## 4. 四检结果

```text
dart format packages/core_alignment apps/app/lib/features/reader apps/app/test
  → 无变更（复跑 0 文件改动）
dart analyze --fatal-infos --fatal-warnings（apps/app）
  → No issues found!
dart run tool/check_imports.dart
  → OK（core_* 未引入 Flutter/平台包）
flutter test --coverage（apps/app） → 174 项全部通过
dart test（core_alignment） → 40 项全部通过
dart test（core_reader_layout） → 24 项全部通过
dart run tool/check_coverage.dart
  [app] 82.8% (3038/3671 行, 要求 >= 70%) OK
  [core_alignment] 91.2% (320/351 行, 要求 >= 85%) OK
  [core_reader_layout] 93.8% (226/241 行, 要求 >= 85%) OK
```

## 5. 行为说明

- 篇尾判定：`_started && !_paused`、锚点为末行、位置到达滚动边界；语音模式额外要求 `ReadingFollower.atRest`，连续静止 0.6 s 才进入 finished，避免 partial 短暂停顿误判。
- 默认停止：置 finished、暂停跟随、显示「已到篇尾」；手动模式在控制区显示同一文案，语音模式沿用状态条。
- 循环：1.2 s 后复位跟踪器/闸门/early arm 与锚点，`jumpToWithFade` 回到第 0 视觉行并解除冻结；语音与录制会话保持原样。finished 时手动点播放/轻点页面同样按循环复位处理。
- early arm：逐行闸门未推进时，若当前行已读 ≥ 55% 且识别尾部与下一行前 2 个 token 模糊全命中，连续 2 次或 final 才把目标提前 1 行；仍经过一阶跟随，不会瞬移。
- 设计偏差：设计稿的命中率公式（档位阈值 − 0.10）在 2 token 下等价于「2 个里命中 1 个」，容易因行尾虚词误触发；实现收紧为「前缀全部命中」，严格档关闭、宽松档只放宽 `margin`。
- 重排：`_maybeAutoReflow` 改为 `_rebuildLines(keepVoice: _voiceOn)`，重建语义行/索引/跟踪器后调用 `restartWith`；不重开麦克风、不重建 ASR 引擎，并记录 `voice/align_restart` 耗时。
- 复位：开始、恢复、跳行、停止语音、循环复位、重排都会取消 `_loopTimer`、清零 `_endRestMs` 与 early arm 计数，防止跨状态沿用旧判定。
- 遥控/悬浮窗：篇尾暂停自然映射为 `playing=false`，循环复位后恢复 `playing=true`；语义行号与 `layoutVersion` 语义未变。
