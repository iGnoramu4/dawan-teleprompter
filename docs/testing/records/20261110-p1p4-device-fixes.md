# 2026-11-10 真机缺陷修复记录（P1 换行丢失 / P2 跟随卡住 / P3 跳读与回跳 / P4 去分段）

## 环境

- 设备：`adb -s f37aa514`（Xiaomi 24091RPADC，Android 16，2136×3200，density 3.128）
- 包名：`com.tp.prompter.teleprompter`（历史构建；当前包名见 [包名变更说明](../../help/package-rename.md)）
- 构建：`$HOME/flutter-sdk/arm64/flutter/bin/flutter build apk --release`
- 修复前构建：0.23.0+2026，仅含 P1 测量器切分修复（下文「修复前」）
- 修复后构建（取证用）：P1–P4 全部改动，未含最后的 `dart format` 空白格式化（无语义差异）
- 交付构建：**0.24.0+2027**，`dist/teleprompter-0.24.0-android.apk`，396,767,776 B，SHA256 `7a4a2cb5fb7ebee58b2e7efc05e31e6b2c06e55f1ebd8e1d58845f88428e8038`，debug 证书（`CN=Android Debug`），相对 0.23.0 的 396,751,372 B **+16,404 B**；已装机确认 `versionName=0.24.0`、`versionCode=2027`。详见 `docs/releases/0.24.0.md`。

## P1 段落内换行文字不显示

### 复现（实测，修复前构建）

- 台本：单段内 `…\nSECOND_LINEMARKER_SHOWME…`，进度显示 3 行，屏幕上只有 2 行可见，第三条视觉行整行空白。
- 语义树取证：第三条视觉行文本以 `\n` 开头（uiautomator dump 十六进制 `0a`），而该视觉行容器固定为单行高度 → 首字符换行先把行高吃掉，正文被挤出裁剪区。
- 结论：**视觉行切分未按硬换行切段** 是根因；不是宽高约束或滚动裁剪。

### 修复

- `apps/app/lib/features/reader/visual_row_measurer.dart`：`FlutterRowMeasurer` 先按 `\r\n` / `\r` / `\n` 切硬行（保留空段、首尾换行），再逐段用 `TextPainter.getLineBoundary` 折行；`getLineBoundary` 返回零长区间时把剩余文本整体作为一行兜底。
- `reader_page.dart`：视觉行渲染统一 `maxLines: 1, softWrap: false, overflow: TextOverflow.visible`。
- 回归测试：`apps/app/test/visual_row_measurer_test.dart`（段内 `\n`、`\r\n`、连续换行、首尾换行、空段；4 字号 × 4 宽度 × 2 行高倍率全覆盖且无换行回退）、`apps/app/test/reader_newline_test.dart`（3 字号 × 3 屏宽含横屏，断言无行以 `\n` 开头、换行后文字可见）。

### 修复后（实测，最终构建）

| 场景 | 证据 |
| --- | --- |
| 竖屏 44px | `images/20261110-p1-final-44.png`（换行后文字完整，进度 1/5） |
| 横屏 52px | `images/20261110-p1-final-landscape52.png` |
| 横屏 36px | `images/20261110-p1-final-landscape36.png` |

修复前对照：`images/20261110-p1-before.png`；修复后：`images/20261110-p1-after.png`、`20261110-p1-after-font52.png`、`20261110-p1-after-landscape.png`。

## P2 语音跟随卡住且提示「未收音」

### 复现（实测，修复前构建）

1. 阅读页开始跟读，`cmd appops set … RECORD_AUDIO ignore` 撤掉采集后：角标仍为「未检测到语音」，底部仍显示「跟读中（麦克风）… 置信 0% · 解码 0 ms」——**采集已不可用却按「没听到声音」呈现**（`images/20261110-p2-before-stalled.png`）。
2. `appops … allow` 恢复后等待 14 s，角标仍停在「未检测到语音」，不重开采集（`images/20261110-p2-before-no-recover.png`）。

### 修复

- 新增 `features/reader/voice_health.dart`：`VoiceHealthKind { idle, capturing, silent, captureStalled, engineStalled }`，依据「音频分片时间 / 解码心跳（`AsrTick`）/ 文本更新时间」三路计数区分原因；阈值 2.5 s / 3 s / 4 s。
- `voice_follow.dart`：订阅 `AsrEngine.ticks`；采集 `onDone/onError` 立即判 `captureStalled`；看门狗每秒评估，`captureStalled` 且距上次重试 ≥3 s 时 `cancel → stop → 重开`，写 `voice/capture_restarted` / `voice/capture_restart_failed`。
- `mic_status.dart`：优先级 后台 > 暂停 > 加载 > **采集中断** > **引擎卡死** > 低置信 > 静音 > **闸门卡住** > 正常；新增文案 `micStatusCaptureLost`（麦克风中断，正在重连…）、`micStatusEngineStalled`（识别引擎无响应）、`micStatusGateStalled`（已收音，未匹配稿件）。
- 阅读页新增 `gateStalled`：有识别文本但锚点 >6 s 未动 → `voice/gate_stalled` 日志 + 对应角标。

### 修复后（实测，最终构建）

- `images/20261110-p2-after-health-logs.png`：诊断日志逐条区分原因与计数：

```
{"tag":"voice","event":"health","kind":"silent","sinceChunkMs":55,"sinceTickMs":371,"sinceTextMs":4346,"chunks":724,"ticks":108,"texts":56,"restarts":0}
{"tag":"voice","event":"health","kind":"capturing",…}
{"tag":"voice","event":"gate_stalled","line":0,"confidence":0.4,"sinceAdvanceMs":18777}
{"tag":"voice","event":"follow_update","line":0,"confidence":0.4,"degraded":true,"decodeMs":65.26}
```

  `chunks / ticks / texts` 三路计数分离：采集停 → `chunks` 不再增长（`sinceChunkMs` 增大）；引擎无帧 → `ticks` 停；只是没说话 → 两者正常、`texts` 不前。

- **局限（实测结论，非推断）**：Android 的 `appops … ignore` 与系统静音开关对正在录音的 `AudioRecord` 表现为「喂静音」而不是关闭流，因此真机上只能稳定复现 `silent` 档，未能构造真实断流。**「断流自愈」（`captureStalled` 判定 + 每 3 s 自动重开采集）目前只有单测覆盖，未在真机验证，不计入本轮已修复项**，需真人朗读/真实断流场景复核；判定与重连逻辑由 `apps/app/test/voice_health_test.dart`（三类分开判定、采集关闭立即判定、重连恢复计数）与 `voice_follow` 看门狗用例覆盖。

## P3 跳读与回跳

### 跳读（实测对照）

- 台本：11 个旧分段（前 8 段为「填充…不会被念到」，末 3 段为演示稿）；`assets/test_wavs/demo_zh.wav` 经 Mac 扬声器外放送入手机麦克风。
- 修复前：起始 `1 / 21`，播放约 15 s 后到 `19 / 21`（置信 95%），**跳过 18 个视觉行**（`images/20261110-p3-before-jump.png`）。
- 修复后：同一台本、同一音频连播 5 次，始终 `1 / 21`，置信 40%，角标「低置信」「低置信降级」（`images/20261110-p3-after-nojump.png`）。

### 修复（三条通道 + 三条回跳路径）

- `line_step_gate.dart`：`delta > maxLeap` 先夹到 `currentLine + maxLeap`，且仍需达到 `confirmConfidence` 才推进；弱置信要连续两次；低置信不推进。
- `tracker.dart`：`candidate > line + 5` 也要求 `rawConfidence >= acceptFloor`（去掉 `|| isFinal` 无条件放行）；任何 `candidate < _line` 一律 `heldBack`，删除 `_pendingBackLine/_pendingBackHits`。
- `aligner.dart`：`lookAheadLines` 8→3，预筛只向前看 `[currentLine, currentLine + lookAhead]`（不再回看 `currentLine-2`）；`match_tolerance.dart` 三档 5/8/12 → 2/3/4。
- 阅读页 `_advanceTo` 单调守卫（`target < _anchor` 直接返回、同锚点字符不退）；平滑模式只向前；删除 `isFinal` 段内字符后退；early arm 仅在 `align.confidence >= weakConfidence` 时参与。
- 短尾捷径：`early_arm.dart` 下一段 ≤3 token、当前行已读 ≥0.95、再下一段（≤3 token）被识别尾部（总长 ≤4）完整覆盖时一次瞄准两段之后；仍要求连续 2 次或 final。**未**采用「缓冲裁到 2 行」的做法。
- 阈值口径未改动（`conf = 1 - spanError/(span*1.2)`），阈值重标留待按 `spanLength` 分桶后单独给出同口径对照。

### 回跳（实测 + 用例）

- 实测：修复后在 `19/21` 位置重复播放同一段音频，进度未回退（`images/20261110-p3-before-noback.png` 为修复前同场景，亦未回退；该次未复现回跳）。回跳路径以回归用例固定：`packages/core_alignment/test/alignment_test.dart`（连续两次回退候选也不回退、final 也不回退、远处低置信不进）。

## P4 去掉分段

- 提词页：模型始终由 `ScriptDocument.rawText` 构建（为空时回退 `joinSections`），按整篇连续文本渲染；进度显示为纯文本（点击不再弹「跳转到段落」对话框）。
- 旧数据迁移：`mapMarkersToContinuousLines({sections, markers, lines})` 按分段 `ord` 顺序把旧标记映射到连续文本的语义行，`charOffset` 夹到行文本长度；`mapLegacyAnchorToParagraphs` 改为按分段顺序返回行号，不依赖 `line.sectionId`；旧断点定位为「分段顺序 → 语义行 → 视觉行」。
- 遥控：`RemoteCommand` 新增 `int? line`，`jump` 同时接受 `line` 与旧 `sectionId`；阅读页优先按 `line` 跳转。
- 悬浮窗/外接屏：继续下发视觉行 `lines`，锚点用连续行号；旧接收端按旧字段回退。
- 时间轴：`TimelineSample` 的段落坐标经 `mapLegacyAnchorToParagraphs` 迁移后映射到连续行，文件仍保存原文坐标。
- 保留项说明：`sections` 仍作为编辑与旧数据字段存在（编辑器/导入页仍按段编辑与统计），提词页不再出现分段概念。

### 修复后（实测，最终构建）

- `images/20261110-p4-after-progress-readonly.png`：点击进度无对话框。
- `images/20261110-p4-after-legacy-mapped.png`：11 个旧分段连续渲染为 21 个视觉行，旧标记「起点」「第二段标记」落在对应行并显示高亮。
- 修复前对照：`images/20261110-p4-before-section-dialog.png`（点击进度弹出「跳转到段落」）。

## 测试与四检（最终构建源码）

| 项 | 结果 |
| --- | --- |
| `dart analyze lib test`（apps/app） | No issues found |
| `dart analyze`（packages：core_alignment / core_models / core_reader_layout / core_recording / core_scroll / data_store / asr_kit / design_system / overlay_bridge） | 全部 No issues found |
| `flutter test`（apps/app） | 210 项通过 |
| `dart test`（packages 6 个有测试的包） | 147 项通过（59/33/24/12/4/15） |
| `flutter test --coverage` + `tool/check_coverage.dart` | 34 文件 79.6%（3229/4054，≥70%）OK |
| `dart format --set-exit-if-changed` | 133 文件 0 变更 |
| `tool/check_imports.dart` | OK |

## 真人朗读自测清单（8 条）

| # | 自测项 | 怎么测 | 本轮状态 |
| --- | --- | --- | --- |
| 1 | 段落内换行文字完整 | 打开含段内换行的台本，字号 36/44/52 与横屏各看一遍 | 已修，设备已验证，可直接复核 |
| 2 | 连续文本、无分段 | 打开旧分段台本：正文连续、进度只读、无「跳转到段落」 | 已修，设备已验证，可直接复核 |
| 3 | 旧标记/断点位置 | 旧台本打开后确认旧标记落在原位置、断点回到原处 | 已修，设备已验证，可直接复核 |
| 4 | 正常朗读不跳读 | 真人匀速朗读一篇 ≥10 段的稿子，观察是否越过未读段落 | **需真人朗读确认** |
| 5 | 朗读中不突然回退 | 同一篇稿子连读 2–3 分钟，观察锚点是否后退 | **需真人朗读确认** |
| 6 | 慢读、停顿、重复句不卡 | 故意放慢、停顿 3–5 s、重复上一句，观察是否卡住或抢行 | **需真人朗读确认** |
| 7 | 角标文案与实际一致 | 静音时应显示「未检测到语音」；持续说话但稿件对不上时显示「已收音，未匹配稿件」 | 部分设备验证，**语义需真人确认** |
| 8 | 断流后自动恢复 | 朗读中切后台/来电/被语音助手抢占麦克风，回到前台看是否自动重连 | **未在真机验证（仅单测），不计入已修复** |

## 实测与推断分界

- 实测：P1 三种字号 / 横竖屏渲染；P2 撤权限前后角标与日志字段；P3 跳读行数前后对照；P4 连续渲染、进度只读、旧标记映射。
- 推断/未构造：P2 的 `captureStalled` 真机断流（受 Android 静音行为限制），由单测覆盖；P3 的「突然回到更前面」未在真机复现，按代码路径收敛并有回归用例；P4 悬浮窗/遥控/时间轴以 widget 与包级测试验证，未逐项真机抓包。
