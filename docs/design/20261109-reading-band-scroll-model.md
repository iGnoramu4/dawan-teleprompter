# 阅读页「固定阅读带 + 视觉行」显示与跟随滚动重设计

> 状态：已实现（阶段 A/B/C）｜日期：2026-11-09｜维护：FE｜构建：`0.21.0+2024`
>
> 范围：阅读页固定阅读带、视觉行、一阶跟随、early arm、篇尾、重排热替换，以及悬浮窗/外接屏/遥控的复用。
>
> 实现记录：[阶段 A](../testing/records/20261109-reading-band-stage-a.md)、[阶段 B](../testing/records/20261109-reading-band-stage-b.md)、[阶段 C](../testing/records/20261109-reading-band-stage-c.md)。
>
> 关联：[20261106-reader-state-machine.md](./20261106-reader-state-machine.md)、[20261106-overlay-window.md](./20261106-overlay-window.md)、[../api/remote-protocol.md](../api/remote-protocol.md)。
>
> 代码路径以工程根 `teleprompter/` 为基准；反编译产物位于
> `<本地反编译工作目录>`（`jadx_out/sources`、`apktool_out/res`）。

---

## 0. 结论摘要

> 事实边界：本文标【事实】的内容可在代码或反编译产物中逐行复核；标【推断】的是由结构/公式推导出的行为判断（如耗时、体感），尚未真机实测；标【未验证】的是必须做设备验收的项。§8 给出证伪方式。

1. **现状的锚点单位不是段落，而是「语义行」**（按 `。！？；` 断句、超长再按逗号切），滚动目标是行顶，靠正文顶部 35% 的占位实现「当前行在 35%」。真正导致「节奏不匹配」的不是行/段单位，而是：**高亮按行号身份先跳到 35% 下方，文字再用弹簧追上来**。眼睛看到的是一个会移动的高亮块，而不是固定在阅读位置、由文字主动走过来的当前行。
   - 证据：[script_model.dart:24](../../teleprompter/packages/core_models/lib/src/script_model.dart#L24)、[reader_page.dart:1036](../../teleprompter/apps/app/lib/features/reader/reader_page.dart#L1036)、[reader_page.dart:1160](../../teleprompter/apps/app/lib/features/reader/reader_page.dart#L1160)、[reader_page.dart:1171](../../teleprompter/apps/app/lib/features/reader/reader_page.dart#L1171)。
2. **小白提词器真正值得借鉴的是「固定焦点行 + 文本在下面走」的坐标关系，而不是它的拼音阈值**：整篇一个 TextView，按 `Layout` 的视觉行切分；焦点行默认距顶 100 dp 且可拖；TextView 的 `paddingTop` 等于焦点行 top，所以「滚到某行」就是把该行顶对齐焦点行；当前行不重新着色，只有固定框和固定的两条横线。
   - 证据：`XBPrompterLayout.java:1616`（paddingTop）、`PrompterHelper.java:223`（默认 100 dp）、`XBPrompterLayout.java:705-708`（行顶）、`XBPrompterLayout.java:780-783`（焦点框高度=行高）。
3. **新方案 = 固定阅读带（band）+ 视觉行几何 + 一阶限速跟随（无过冲）**：屏幕上的阅读带不动，文字以「视觉行」为单位走到带内；语义行只用于语音对齐、断点、遥控和分段。先统一一套坐标模型，再让主阅读页、悬浮窗、外接屏复用同一套「锚点行 + 可见窗口 + 带位置」，最后才调语音阈值。
   - 依据：小白的事实（固定焦点、行顶对齐、小步位移短、越级跳转快）→ 我们的问题（高亮先跳、弹簧后追、每帧全量重排）→ 取舍见 §3。

---

## 1. 现状核对（只陈述代码事实，推断单独标注）

### 1.1 阅读单位与断行

【事实】

- 行来自 `ScriptModel`：先按句末标点 `。！？!?；;` 断句，超过 `maxLineChars` 再在 `，,、：:` 等软断点处切；仍超长则硬切。
  - `script_model.dart:24-25`、`script_model.dart:35-110`。
- `maxLineChars` 由 `LineFit` 按「舞台宽度 − 14 px、字号、字距、台本平均字宽」自动计算，夹在 `[6, 80]`。
  - `line_fit.dart:9-16`、`line_fit.dart:52-67`；调用处 `reader_page.dart:1016-1034`。
- 因此**一行是一条语义行（句或逗号分句），不是段落**；阅读页的锚点、高亮、遥控行号都以这个「语义行」为单位。
- 一行的实际渲染高度由 `TextPainter` 测量后加垂直内边距，间距再额外加 `lineGap`；测量宽度是 `stageWidth - 14`，与渲染时 `6 px 高亮条 + 8 px 间隙` 恰好一致。
  - `reader_page.dart:1052-1063`、`reader_page.dart:1182-1204`、`tokens.dart:45-46`。

【推断】

- 语义行长度随屏幕宽度在 6–80 字之间变化，因此「多久切一次行」在不同设备/横竖屏上差异很大；同一套弹簧参数无法同时适配「7 字一行」和「21 字一行」的节奏。

### 1.2 页面布局与坐标

【事实】

- 页面没有 `ScrollView`：全部行放在一个 `Column` 里，外层用 `Transform.translate(0, -offset)` 移动；因此不会触发文本重新布局，但**所有行的 Widget 都会参与构建**。
  - `reader_page.dart:1145-1169`、`reader_page.dart:1120-1127`。
- 正文列顶部先放 `viewportH × readAheadRatio` 的空白（默认 0.35），底部放 `viewportH × 0.8` 的空白；锚点行行顶滚到 `tops[line]` 时，视觉上位于视口的 35%。
  - `reader_page.dart:1160-1164`、`reader_page.dart:1067-1074`。
- 当前行/下一行/其余行的颜色与高亮条按 `index == _anchor`、`index == _anchor + 1` 决定；高亮块跟着行号走。
  - `reader_page.dart:1171-1178`、`reader_page.dart:1182-1204`。
- `readAheadRatio` 同时存在于 `ReaderSettings`（0.2–0.6）和 `ScrollPlanner`（构造参数），但 `ScrollPlanner` 内部**从未使用**该字段；实际 35% 完全由正文顶部的 `SizedBox` 决定。
  - `reader_settings.dart:78-79`、`scroll_planner.dart:16`、`scroll_planner.dart:35`。
- 顶部状态条、底部控制面板、麦克风角标都是 `Stack` 覆盖层，不参与正文的安全区计算；面板 3 s 后淡出。
  - `reader_page.dart:1102-1139`、`reader_page.dart:1264-1272`。

【推断】

- 「35%」只描述了静止时刻；运动过程中当前行并不在 35%，而高亮已经先跳到了新行，于是视觉锚点在屏幕上是漂移的。
- 顶部 35% 的占位与 `ScrollPlanner.readAheadRatio` 形成两套真相；未来改带位置时容易只改一处。

### 1.3 滚动模型

【事实】

- `ScrollPlanner` 是二阶弹簧：默认 `omega=8`、`zeta=0.9`、常态最大速度 600 px/s、跳读 1200 px/s、目标去抖 80 ms。
  - `scroll_planner.dart:10-17`。
- 去抖后目标与当前目标差小于 `0.5 × lineHeight` 时不更新；大于 `5 × lineHeight` 视为跳读、立即提交目标并启用快速追赶。
  - `scroll_planner.dart:89-103`。
- 每帧积分弹簧，速度夹在 600/1200 px/s；位置与目标差小于 0.05 px 且速度小于 0.5 px/s 时吸附。
  - `scroll_planner.dart:143-173`。
- `lineHeight` 传的是估算值 `fontSize × lineHeight + lineGap`（默认 44×1.5+24.2≈90.2 px），而实际行距是 `TextPainter.height + 2×0.14×fontSize + lineGap`（默认约 66+12.3+24.2≈102.5 px）。
  - `reader_page.dart:1042-1043`、`reader_page.dart:1049-1062`、`reader_settings.dart:221-223`。
- 手动跳段/上一行/下一行走 `jumpTo`，位置瞬间改变，没有过渡。
  - `reader_page.dart:1955-1969`。
- 手动拖拽时 `nudge` 直接改位置，松手后没有「吸附到行边界」；语音模式下拖拽会冻结规划器，松手后把跟踪器强制到当前锚点。
  - `reader_page.dart:1290-1312`、`scroll_planner.dart:118-125`。

【推断】

- 在默认排版下，一行约 102 px；弹簧整定时间按 ζ=0.9、ω=8 估算约 0.5 s 到 97%，0.6–0.8 s 才完全静止。7 字一行、4 字/秒的语速下约 1.75 s 切一行，于是**约三分之一的时间文字都在缓动**，形成「顿一下、再滑一下」的呼吸感。
- `lineHeight` 估算值偏小约 12%，导致死区、5 行跳读阈值、手动滚动速度都按偏小的行距计算；这会放大「手动速度和语音速度不一致」的体感。
- 跳读时弹簧仍要走过 3×102 px，600/1200 px/s 的上限会把它拉成约 0.5–0.8 s 的追赶；而参照实现超过 2 行是约 250 ms 的平台平滑滚动。

### 1.4 高亮、预读与语速

【事实】

- 只有当前行和下一行有特殊颜色；其余行统一 `dimText`。下一行不透明度 0.72。
  - `reader_page.dart:1171-1178`、`tokens.dart:48`。
- 高亮是「行号身份」：`_anchor` 一变，新行立刻着色，即使它还在阅读带下方约一行处。
  - `reader_page.dart:1171-1178`、`reader_page.dart:2437-2459`。
- 行内没有任何进度提示；`AlignResult.anchorToken` 已经算出命中的 token，但阅读页只用 `tracker.line`。
  - `aligner.dart:7-21`、`reader_page.dart:2422-2424`。
- 重点标记（emphasis）在行内画底色，但会把文字颜色强制设回 `_palette.text`；在被压暗的行上，标记词仍是最亮的，破坏焦点。
  - `reader_page.dart:1239-1247`。

【推断】

- 用户说「视觉节奏与滚动不匹配」，最直接的来源是：**高亮先跳、文字后追**。高亮出现在带下方，眼睛被拉下去；随后整块文字向上滑，眼睛再跟回来。参照实现没有这个问题，因为焦点框不动、当前行也不重新着色。
- 行内无进度意味着一条 21 字的长行要等 4–5 s 才动一次；而 7 字的短行 1.5 s 就动一次。节奏的「颗粒度」本身在变，弹簧无法同时匹配。

### 1.5 语音跟随的推进与回退

【事实】

- `AlignEngine`：拼音命中率预筛（当前行前 2 行到后 `lookAheadLines` 行，标准档 8 行）+ 窗口单调 DP（200 token 窗口、40 带宽）；置信度是 `1 - cost/(m×1.2)`，不是行命中率。
  - `aligner.dart:40-53`、`aligner.dart:117-142`、`aligner.dart:144-219`。
- `AlignTracker` 再做一次接受/回退抑制：候选落后超过 2 行默认丢弃，连续 2 次或 final 才回退；候选前进超过 5 行标记 `fastCatchUp`。
  - `tracker.dart:131-159`。
- `LineStepGate` 再做第三次判定：强命中 ≥0.55（final +0.15）立即切；弱命中 0.35–0.55 连续 2 次；单次最多前进 3 行；候选 ≤ 当前行不推进。
  - `line_step_gate.dart:47-56`、`line_step_gate.dart:99-142`。
- 因为闸门明确拒绝 `candidateLine <= currentLine`，**`lineStepFollow=true` 时 tracker 的回退候选永远到不了 UI**；回退只在平滑模式（直接采用 tracker 行）或手动操作时发生。
  - `line_step_gate.dart:114-126`、`reader_page.dart:2437-2459`。
- 标准档/严格档/宽松档的阈值集中在 `MatchProfile`，三档确实一处驱动闸门、预筛和跟踪器。
  - `match_tolerance.dart:62-99`。
- 每次 ASR 更新（包括 partial）都 `setState`，并且 `lineStepFollow` 打开时只有闸门允许才 `setTarget`；平滑模式则每次更新都设目标。
  - `reader_page.dart:2409-2462`。
- 没有「读到篇尾」的状态：候选到末行后闸门不再推进，规划器停在末行；没有 `finished` 事件、没有循环、没有自动暂停。
  - `line_step_gate.dart:114-126`、`scroll_planner.dart:64-69`。

【推断】

- 三层阈值串联（预筛 → tracker 接受 → gate 确认）增加了切行延迟；尤其 partial 很短的早期，候选行可能已经正确，但 gate 还要等下一次命中。
- 没有「下一行前缀提前触发」：必须等跟踪器/闸门确认候选行才动，而参照实现会在当前行尾部与下一行前 4 个 token 匹配时提前跨行。这是「念到了才动」和「念到前就到位」的差别。

### 1.6 重排与锚点

【事实】

- 每次 `build` 都调用 `_prepareLayout`；`_maybeAutoReflow` 在每行字数变化时安排一个帧后回调，**先 `_stopVoice()`，再 `_rebuildLines()`**。
  - `reader_page.dart:1036-1039`、`reader_page.dart:1016-1034`。
- `_rebuildLines` 用「段 id + 段内起始偏移」恢复位置；重建 `ScriptIndex` 和 `AlignTracker`（tracker 从第 0 行开始），递增 `layoutVersion`，清空闸门，重新推送悬浮窗 `init`。
  - `reader_page.dart:238-270`。
- `_stopVoice` 在录制中会级联 `_toggleRecord()`，即重排不仅停麦，还可能把录制切成两段。
  - `reader_page.dart:2382-2407`。
- 语音重新开始时会 `_tracker.forceLine(_anchor)`，所以 tracker 归零不会永久错位，但必须重新点麦克风。
  - `reader_page.dart:2288-2292`。

【推断】

- 旋转、分屏、折叠屏展开、改字号都会触发重排；当前实现把这些日常操作都变成「停麦/停录 + 重新开始」，这是比滚动曲线更伤连续性的问题。
- 用段内行起始偏移恢复，粒度是「行首」而不是「行内字符」；重排后可能回到同一段更靠前的一行。

### 1.7 三端（主页面 / 悬浮窗 / 外接屏）

【事实】

- 悬浮窗只接收 `lines + anchor`，3/5 行窗口把锚点放在中间（`_anchor - count/2`），没有阅读带、没有动画；全稿模式用 `ListView`，锚点变化时**不会自动滚动**。
  - `overlay_app.dart:370-419`、`overlay_app.dart:384-394`。
- 外接屏原生只画 5 行，整块垂直居中，锚点行在中间；无动画，每次 `update` 全量重建 `TextView`；`maxLines=3` 可折行。
  - `ExternalDisplayController.kt:33-35`、`ExternalDisplayController.kt:181-208`。
- 主页面 35%、悬浮窗/外接屏约 50%，三端没有共享的带位置/可见行模型，只有 `anchor` 行号相同。
  - `reader_page.dart:1160`、`overlay_app.dart:415-418`、`ExternalDisplayController.kt:188-193`。

【推断】

- 同一个锚点在三种屏幕上的「眼睛位置」不同；如果做遥控/校准，用户需要分别适应。
- 全稿模式不跟随，是已知限制，但在「固定阅读带」方案里可以自然消掉。

### 1.8 性能与构建路径

【事实】

- `_prepareLayout` 在 `build` 内同步执行，对**每一行**创建 `TextPainter` 并 `layout`；随后 `_buildStage` 为**每一行**创建 Widget，全部放进 `Column`。
  - `reader_page.dart:1052-1063`、`reader_page.dart:1095-1097`、`reader_page.dart:1161-1163`。
- `_onVoiceUpdate` 每个 ASR 更新都 `setState`（partial 也包含），因此识别频率有多高，全量测量/构建就有多高。
  - `reader_page.dart:2425-2432`。
- 手动滚动切行时 `_syncAnchorFromPosition` 也会 `setState`。
  - `reader_page.dart:996-1009`。

【推断】

- 1000 行的台本、5 Hz 的 partial 更新，相当于每秒约 5000 次 `TextPainter.layout` 和 5000 个 `Text` Widget 的 diff；即使文字没有变化，这也会抢走帧预算，表现为滚动偶发掉帧。具体帧耗时未实测，需按 §9 补测；但代码路径是确定的。
- `Transform` 避免了文本重新布局，却挡不住「每帧重建整棵 Column」的成本。

### 1.9 诊断清单（按优先级）

| # | 问题 | 证据 | 影响 | 级别 |
|---|---|---|---|---|
| D1 | 高亮按行号身份先跳到带下方，文字再用弹簧追 | `reader_page.dart:1171-1178`、`2437-2459` | 眼睛追高亮；当前行在运动中不在固定位置 | P0 |
| D2 | 弹簧整定 0.6–0.8 s，且每行一个 ~102 px 的步进 | `scroll_planner.dart:10-17`、`143-173` | 每 1.5–2 s 一次「缓动—静止」，节奏与语速脱节 | P0 |
| D3 | 语义行长度 6–80 字可变，行内无进度 | `line_fit.dart:52-67`、`aligner.dart:7-21` | 切行颗粒度随设备变化；长行长时间不动 | P1 |
| D4 | 规划器行距用 90.2 px，实际约 102.5 px；未计入 textScaler | `reader_page.dart:1042-1043`、`1049-1062` | 死区、跳读阈值、手动速度全部偏小 | P1 |
| D5 | 每次 ASR partial 全量测量 + 重建所有行 | `reader_page.dart:1036-1063`、`2425-2432` | 掉帧，进一步破坏滚动平滑 | P0（推断为体感） |
| D6 | 重排先停麦，录制中还会切分录制；tracker 重建归零 | `reader_page.dart:1016-1034`、`238-270`、`2382-2407` | 旋转/改字号/分屏即中断 | P1 |
| D7 | 没有可视行数/安全区夹取；35% 固定，字号 160 时只剩约 1 行 | `reader_page.dart:1160`、`reader_settings.dart:144、152` | 极端排版下高亮带出屏/遮挡 | P2 |
| D8 | 三端各自一套坐标；悬浮窗全稿模式不跟随 | `overlay_app.dart:410-419`、`ExternalDisplayController.kt:181-193` | 体验不一致，无法共用校准 | P2 |
| D9 | 篇尾无完成态；跳段瞬间位移 | `line_step_gate.dart:114-126`、`reader_page.dart:1962-1969` | 缺少结束反馈；大跳变刺眼 | P2 |
| D10 | 重点标记在暗行上强制高亮文字色 | `reader_page.dart:1239-1247` | 破坏焦点层级 | P2 |

---

## 2. 参照实现拆解（小白提词器 3.3.1）

> 说明：以下「事实」来自反编译产物；`XBPrompterUtils.d/e` 的循环体在 jadx 中缺少匹配条件（空 `if` 块），**命中率的逐行实现不能当作可靠事实**，只能确认阈值表达式与调用位置。

### 2.1 渲染与坐标

【事实】

- 整篇稿件放在一个 `TextView` 中，按 Android `Layout` 的视觉行读取行边界：
  - `XBPrompterLayout.java:705-708`：`getLineBounds(0)` 与 `getLineBounds(i2) - lineBounds` 得到第 i 行的行顶偏移；
  - `XBPrompterLayout.java:741-748`：行高优先用 `getLineBounds(1) - getLineBounds(0)`，失败回退 `getLineHeight()`；
  - `XBPrompterLayout.java:989-1017`：`h(scrollY)` 反查最近行，`i(line)` 返回该行行顶。
- 焦点框 `XBAttentionLayout` 默认距顶 100 dp，可上下拖动并持久化：
  - `PrompterHelper.java:223`（默认 `UIUtils.a(context, 100.0f)`）；
  - `XBPrompterLayout.java:530-568`（拖动回调写入 `key_attention_top_border`）。
- 焦点框高度跟随当前行高；`TextView` 的 `paddingTop` 被设为焦点框 top，`paddingBottom` 设为「屏高 − 焦点 top」，从而保证首行能停在焦点行、末行也能滚到焦点行。因此「滚到某行」只需把该行行顶对齐滚动视图顶部，视觉上就落在焦点框：
  - `XBPrompterLayout.java:780-783`（焦点框高度 = `getLineHeight()`）；
  - `PrompterActivity.java:449-464`（焦点 top 与底部留白）；
  - `XBPrompterLayout.java:1616`（`textView.setPadding(rect.left + width, rect.top, ...)`）；
  - `XBPrompterLayout.java:1594`（`setTextSize` 默认 28sp，来自 `PrompterHelper.f26764i`）。
- 水平边距：基础 10 dp + 按屏宽比例的「滚动边距」设置；对齐方式 0/1/2（左/中/右）来自 `PrompterHelper.f26763h`。
  - `XBPrompterLayout.java:1616` 之前的 `width` 计算；`PrompterHelper.java:82`。
- 排版：默认字号 28sp；未发现 `setLineSpacing` 调用，行高直接取系统 font metrics 的 `getLineHeight()`，即约 1.15–1.3 em 的自然行距，没有我们这种 1.5 倍字高再加 0.55 em 额外间隙的松排版。可视行数没有单独设置项，由屏高/行高决定；焦点行默认上方约 2–3 行、下方为剩余空间。
  - `XBPrompterLayout.java:1594`；`XBPrompterLayout.java:741-748`；全仓 grep 无 `setLineSpacing`/`lineSpacingExtra`。
- 镜像：`setScaleX(-1)` / 旋转 180° 作用在滚动层，焦点框不参与镜像。
  - `XBPrompterLayout.java:1636-1656`。

【解读】

- 它没有「每行一个 Widget」的概念：所有行共享一个 `TextView`，所以行高、行距、折行全部由系统排版保证一致；视觉行就是滚动行。
- 焦点框是**屏幕空间**的固定参考，文字通过 `paddingTop` 与滚动偏移「钻到框下面」。这与我们「高亮跟着行号走、文字再追」的坐标关系相反。

### 2.2 滚动

【事实】

- 跳转目标：`c(target)` 设置 `f = target` 后调用 `smoothScrollTo(0, f)`（平台平滑滚动，约 250 ms）。
  - `XBTextScrollView.java:317-320`。
- 当前行变化时按距离分流：
  - 距离 `<= 2` 行：设置目标 `f`，用 5 ms 定时器逐步逼近（`i4 > 2` 才走直接跳转）；
  - 距离 `> 2` 行：直接 `smoothScrollTo`。
  - `XBPrompterLayout.java:640-682`。
- 小步滚动速度不是固定值：`a(contentHeight, lineHeight, charsPerLine)` 计算 `f = charsPerLine × 60 / lineHeight`，映射为 5 ms 内移动 1–6 px，即 200–1200 px/s（`XBTextScrollView.java:279-305`）；定时器每次只走 `e.itemSize`，到目标或到底停止（`XBTextScrollView.java:167-231`）。
- 自动滚动另有 31 档速度表：间隔 1000…4 ms、步长 1…12 px；默认档 6 对应 20 ms、1 px，即 50 px/s。
  - `XBTextScrollView.java:39-42`、`PrompterHelper.java:78`。
- 手动滚动：停止后每 60 ms 检查一次是否静止，静止后吸附到最近行顶（或按行高取整）。
  - `XBTextScrollView.java:234-271`。
- 暂停/恢复时 `abortAnimation` 并清掉 100/101 消息，位置不保留惯性。
  - `XBTextScrollView.java:336-340`。

【解读】

- 小位移是**匀速像素步进**，不是弹簧：没有过冲、没有速度记忆，目标更新时只改终点；大位移用一次短的平台平滑滚动。
- 速度上限与「每行字符数 / 行高」相关，本质是让「一行文字在约 0.1–0.5 s 内走完」，而不是按固定 px/s。
- 焦点框不动，所以位移再大，眼睛的参考点也不动；这是我们最需要复制的部分。

### 2.3 语音推进

【事实】

- 阈值：`0.55 + 0.05 × gain`；`gain` 默认 3，即 0.70。
  - `AIPrompterWrapper.java:199-210`、`PrompterHelper.java:203`。
- 同时预判下一行：若下一行较短（1–3 个词）且 ASR 尾部 4 个 token 与下一行前缀的命中率也过阈值，会先 `i(..., f+1, ...)` 跨到下一行，再按正常逻辑推进。
  - `AIPrompterWrapper.java:204-214`。
- 缓冲区足够长时（`buffer.size >= width + minWordSize`，`width = textViewWidth/(textSize×4)`），在 `[current, current + skipLine]` 内向前搜索命中率最高的行；`skipLine` 默认 3。
  - `AIPrompterWrapper.java:199-240`、`PrompterHelper.java:204`。
- 跨行后保留 ASR 尾部若干 token（按行词数 0–4 个），避免下一行开头被吞掉。
  - `AIPrompterWrapper.java` 的 `b(List)` 映射；调用处 `i(..., offsetWordSize, ..., 4)`。
- 到末行停止推进；是否循环由 `PrompterHelper.f26771q` 控制，末行后延迟重置到顶部。
  - `XBPrompterLayout.java:683-690`、`XBTextScrollView.java:217-229`。
- 拼音混淆表：反编译静态块中可见约 57 条 `map.put`（声母平翘舌、前后鼻音、n/l 等），与逆向文档的「55 条」略有差异，以源码为准。
  - `XBPrompterUtils.java:37-110`。

【推断】

- 阈值 0.70 看似很高，但它的「命中率」分母是 ASR token 数、按词袋匹配，不是编辑距离；与我们的 DP 置信度不可直接比较，不能把 0.70 搬过来。
- 它真正减少延迟的是「下一行前缀匹配」和「跨行保留尾部 token」，而不是阈值本身。

### 2.4 哪些适用、哪些不适用

| 机制 | 是否适用 | 理由 |
|---|---|---|
| 固定焦点行 + 文本走到框下 | **适用** | 直接解决「高亮追眼睛」；与设备形态无关 |
| 视觉行作为滚动单位 | **适用** | 行高一致、几何简单；我们已有行模型，可派生视觉行 |
| TextView `paddingTop = 焦点行 top` | **不直接适用** | 我们是逐行 Widget；用「内容顶垫 + 目标公式」等价实现 |
| 焦点行默认 100 dp | **不适用** | 我们是手持/三脚架/分光镜多形态，100 dp 太靠上；保留比例可调 |
| 5 ms / 1–6 px 步进 | **部分适用** | 思路（匀速、无过冲）适用；具体档位应按我们的字号/行距重新推导 |
| 超过 2 行直接平滑滚动 | **适用** | 越级跳读不能慢慢追；但我们的跳段应更快/淡入 |
| 拼音阈值 0.55+0.05×gain | **不直接适用** | 分母/匹配方式不同；我们已有 DP 置信度与三档 |
| 下一行前缀提前触发 | **适用** | 直接改善「念到才动」 |
| 跨行保留 ASR 尾部 token | **适用** | 我们的 partial 也可能已包含下一行开头 |
| 焦点框可拖、水平边距比例 | **适用** | 与我们的 `readAheadRatio`/`horizontalMargin` 对齐 |
| 单 TextView 全量排版 | **不适用** | 我们逐行有标记、分段、窗口化需求；但可借鉴其「一次测量、行几何缓存」 |

---

## 3. 新方案

### 3.1 设计原则

1. **屏幕锚点不动**：阅读带（band）是屏幕空间固定区域；文字移动到带内，而不是高亮块在屏幕上移动。
2. **几何以测量为准**：滚动、带位置、可见行全部用 `TextPainter` 实测的视觉行几何，不再用 `fontSize × lineHeight` 估算。
3. **视觉行 = 滚动单位；语义行 = 对齐/持久化/遥控单位**：两者解耦，避免「一行太长」或「一行被硬切成两三行」影响坐标。
4. **短位移快速到位，长位移不穿越**：小步 120–220 ms 内完成；跳段/大跳用直接落位 + 短淡入，避免用户看着文字飞过好几屏。
5. **无过冲、无速度记忆**：ASR 目标是阶跃序列，二阶弹簧会在目标中途变化时保留速度，产生「追过头再回来」或「停不下来」；改用一阶限速跟随。
6. **重排不打断收音**：坐标重建与音频/识别解耦；重排只换索引与锚点，不断麦克风、不断录制。
7. **一套模型三端复用**：主页面、悬浮窗、外接屏共享「锚点行 + 可见窗口 + 带位置 + 行几何」，差异只在窗口大小与是否动画。

### 3.2 坐标模型

#### 3.2.1 术语

- **语义行 `ScriptLine`**：`ScriptModel` 的行，带 `sectionId`、`sectionCharStart`；用于断点、遥控、录制时间轴、语音对齐候选。**2026-11-10 起语义行 = 段落**：只按空行切分，段内不再按句号/逗号断行（见 §3.2.6）。
- **段内锚点 `anchorChar`**：当前锚点是「第 `line` 段的第 `charOffset` 个字符」，视觉行由 `rowForChar(line, charOffset)` 推导。
- **视觉行 `VisualRow`**：一次实际渲染的一行文字（单行，不折行）。一个语义行（段落）可以对应 1..N 个视觉行（拉丁文、超大字号、系统字体缩放时）。
- **阅读带 `ReadingBand`**：屏幕空间固定矩形，默认高度 = 一个视觉行的高度，中心在视口高度的 `bandRatio` 处。
- **内容坐标 `contentY`**：从内容顶部（含顶部垫）向下。
- **滚动位置 `position`**：内容整体向上平移的像素数。

#### 3.2.2 视觉行的生成

- 对每个语义行，用与渲染完全一致的 `TextStyle`、`textScaler`、可用宽度 `stageWidth - 14` 做一次 `TextPainter.layout`，取 `computeLineMetrics()`：
  - 只有 1 条 metrics → 1 个视觉行；
  - 多条 metrics → 按每条 metrics 的字符范围切成多个视觉行（用 `getPositionForOffset` 或 metrics 的 `left/width` 反推字符边界）。
- 每个视觉行记录：`scriptLineIndex`、`charStart/charEnd`（相对语义行）、`top`、`height`、`text`。
- **强制单行**：视觉行高度 = `textHeight + 2 × bandPadY`，所有视觉行等高；这样带高、pitch、可见行数都是常量，滚动几何最简单。
  - 若某个语义行的单个字符宽度就超过可用宽度（极端字号/窄窗），允许该视觉行横向裁切并在设置页提示，不引入横向滚动。

> 视觉行是渲染层对段落的自然折行结果：段落本身不因宽度或标点被切开，只有视觉行随宽度变化。

#### 3.2.3 带与目标

- 设视口高 `H`，安全区 `safeTop`、`safeBottom`（见 §3.3），带高 `B = rowHeight`，带中心比例 `r`（默认 0.34）。
- `bandCenter = clamp(safeTop + (safeBottom - safeTop) × r, safeTop + B/2, safeBottom - B/2)`
- `bandTop = bandCenter - B/2`
- 内容顶部垫 `padTop = bandTop`；视觉行 `i` 的 `contentY = padTop + i × pitch`，`pitch = rowHeight + rowGap`。
- **目标位置**：`target(i) = contentY(i) - bandTop = i × pitch`
  - 即第 0 行目标为 0，第 i 行为 `i × pitch`；不再需要「顶部 35% 的 SizedBox」这种隐式偏移。
- 最大滚动：`maxScroll = max(0, (lastRowIndex) × pitch)`；最后一行到带内后，下方留白 `safeBottom - bandTop - B`，不参与滚动。
- 渲染：`Transform.translate(offset: Offset(0, -position))`；带和顶部/底部蒙层在内容层之外，保持屏幕固定。

#### 3.2.4 镜像与分光镜

把变换收口到一个**视口大小的校准层**，避免 `Transform.scale` 以内容高度为中心导致公式不可控：

```
y1 = contentY - position
y2 = mirrorY ? (H - y1) : y1
y3 = y2 + prismDy × H
令 y3 = bandTop
```

- 正常：`position = contentY - bandTop`
- `mirrorY`：`position = contentY + bandTop - H - prismDy × H`
- `prismDx` 只影响水平，不影响滚动目标；`mirrorX` 只翻转水平，带本身左右对称。
- 校准：设置页提供「校准卡」——一条测试线 + 当前行文本，用户拖动 `prismDy` 直到测试线中心与带中心重合；公式与上面一致，不需要用户理解坐标。
- 现有 `prismDx/prismDy` 范围 ±0.05 保持不变；新增 `bandRatio` 校准卡只影响 `r`。

> 现状把 `prismOffset` 作用在包含正文的 `Transform.translate` 上，而 35% 占位在正文内部，所以校准会连同「锚点位置」一起移动；新模型把带放在变换外，目标公式补偿 `prismDy`，带始终在眼睛位置。

#### 3.2.6 段落化与坐标兼容（2026-11-10）

1. **切分规则**：`splitIntoSections` 只按空行（`\n[ \t]*\n`）切段；段内所有文字连续排布，仅按可用宽度自然折行，不再按句号/逗号/120 字切分。
2. **旧台本的边界**：历史版本存储的分段本身是「每 ≤120 字一块」，原始空行边界已丢失。为避免重新切分造成跳位，旧台本按「每个存储分段 = 一个段落」显示，不做二次按空行合并；新导入/新建台本才按空行分段。
3. **断点迁移**：`saveAnchor` 同时写入 `anchor_model:<scriptId>`；旧数据缺省为 `1`。阅读页在 `initialAnchorModel < 2` 时调用 `mapLegacyAnchorToParagraphs`，用 `splitText(section.text, 40)` 重建旧行，把旧行号映射到「段落 + 段内字符」，保证断点不越界。0.17 及更早的切行上限确为 40；0.18–0.21 曾按窗口宽度自动计算且未落库，无法还原，只能按 40 近似，这类旧断点可能偏移少量行。写回时 `anchor_model` 升为 `2`。
4. **时间轴迁移**：时间轴格式版本升至 `2`，采样新增可选 `char`；`positionAt(ms)` 返回 `(line, char)`。v1 时间轴在回放/导出前用同一映射函数迁移；SRT 导出用 `captionIndex` 把「段落 + 字符」折算成视觉行文本，正文时间轴文件仍保存原文坐标。
5. **协议兼容**：遥控协议升至 v3，`anchorLine` 语义明确为段落，新增 `anchorOffset`/`anchorRow`/`rowProgress`/`lineUnit`/`anchorRowText`；v1/v2 上行消息继续接受。旧遥控端忽略新字段、按段落粒度展示，不改变字段类型，不静默回退主机语义。悬浮窗/外接屏的 `init`/`present` 新增 `rows`/`anchorRow`，旧接收端回退到 `lines`/`anchor`。
6. **已知取舍**：段落可能很长（无空行整篇 = 1 段），语音对齐与滚动在段内按字符推进；视觉行数可能远大于段落数，因此进度百分比改按视觉行计算（遥控 `rowProgress`），`progress` 仍按段落计算。

### 3.3 页面布局

#### 3.3.1 安全区

- `safeTop = max(viewPadding.top, 顶部状态条高度) + 8 dp`。顶部状态条/麦克风角标是覆盖层，正常情况下带在 34% 不会与它重叠；当 `bandRatio` 调到下限时用 `safeTop` 兜底。
- `safeBottom = H - viewPadding.bottom - 12 dp - panelReserve`：
  - `panelReserve = 控制面板可见 ? panelHeight : 0`，但面板 3 s 后淡出，**不能让带随面板显隐上下跳**；
  - 因此实际计算用 `panelReserve = min(panelHeight, H × 0.18)` 作为固定预留，面板淡出后下方多出的区域只增加预览行，不改变带位置。
- 带夹取：`bandCenter` 保证上方至少 1 个视觉行、下方至少 2 个视觉行；若 `safeBottom - safeTop < 3 × pitch`，允许只显示 1–2 行，并在设置页显示「当前字号下仅 N 行」提示，不自动改字号。若单行高度 `B > safeBottom - safeTop`（极端字号），带中心取安全区中点，允许上下裁切，不做强制缩放。

#### 3.3.2 可视行数

- `rowsVisible = floor((safeBottom - safeTop + rowGap) / pitch)`。
- 目标：手机竖屏默认排版（44 px / 1.5× 行高）下 7–9 行；横屏 5–7 行；平板/桌面 10–14 行。
- 带上方行数 `rowsAbove = floor((bandTop - safeTop + rowGap) / pitch)`；下方 `rowsBelow = rowsVisible - rowsAbove - 1`。
- 默认 `r=0.34`，在 800 px 高、102 px pitch 下：`rowsAbove≈2`、`rowsBelow≈4`，当前行在 2/7 处，预读 4 行；比现状「35% 但只按行顶算」更明确。
- 设置页仍用「阅读线位置」滑块（0.2–0.6），并把数值解释为「当前行中心在屏幕高度的百分比」，不暴露行数公式。

#### 3.3.3 字号、行高、字距、边距

- 所有几何从测量结果派生，避免估算误差：
  - `textHeight = TextPainter(style).height`（含 `textScaler`）；
  - `rowHeight = textHeight + 2 × bandPadY`，`bandPadY = 0.08 × fontSize`；
  - `rowGap = clamp(0.04 × fontSize, 0.30 × fontSize, gapFromSettings)`；
  - `pitch = rowHeight + rowGap`。
- `letterSpacing` 只改变宽度，不改变行高；宽度由 `LineFit` 用于语义切分，视觉行由实测决定。
- **排版默认值建议（待拍板）**：把 `lineHeight` 重新定义为「行距倍数 = pitch / fontSize」，默认从 1.5 降到 1.55（含 gap），而不是当前的 1.5 + 0.55 gap ≈ 2.05 倍。理由：
  - 当前 44 px 字号下 pitch ≈ 102 px，800 px 高只有 7.8 行，每切一行文字要移动 102 px；参照实现的自然行高约 1.2–1.3 em，移动量小得多；
  - 更紧的 pitch 能在同样高度多显示 2–4 行，预读更充足，单次位移更小，节奏更稳。
  - 迁移：旧预设按 `oldPitch = fontSize × oldLineHeight + oldGap` 反算新倍数并夹在 `[1.0, 2.5]`，保持旧观感；新安装默认 1.55。用户可在设置里选择「紧凑 / 标准 / 宽松」三档（对应 1.45 / 1.55 / 1.75），不引入连续小数。
- 左右边距继续用 `horizontalMargin`（0–0.4，默认 0.06），舞台宽度上限 980 px 不变；视觉行测量宽度 = `stageWidth - 14`。

#### 3.3.4 高亮与蒙层

- 带：`highlightBackground` 以 0.10–0.14 透明度填充，上下各一条 1 px `highlightBar`（透明度 0.35–0.5）作为「台词线」；左侧固定 3 px 竖条，不再随行移动。
- 带外：上方 0.6 屏高做从透明到背景色的渐变蒙层，下方同理；蒙层不拦截触摸。
- 行内 emphasis 标记保留底色，但**文字颜色继承当前行的强调色**，不再强制 `text`；否则暗行上的标记会抢焦点。
- `highlightEnabled=false` 时只保留上下两条细线（仍提供位置参考），不填充背景。

### 3.4 阅读单位

| 用途 | 单位 | 理由 |
|---|---|---|
| 渲染/滚动/带 | 视觉行 | 行高一致、几何简单；与参照实现一致 |
| 语音对齐候选 | 段落（语义行）+ 段内字符偏移 | 段内连续，不再按标点切出短行，避免匹配噪声 |
| 断点/预设/录制时间轴 | 段落 + 段内字符偏移（时间轴 v2） | v1 时间轴读取时按旧切行迁移，见 §3.2.6 |
| 遥控 `anchorLine` | 段落 + `anchorOffset`/`anchorRow`（协议 v3） | v2 遥控端忽略新字段，降级为按段落粒度展示 |
| 悬浮窗/外接屏 | 视觉行窗口 + `anchorRow` | 切片与主页面一致；旧宿主可回退 `lines`/`anchor` |

- 视觉行与语义行的映射由 `LayoutSnapshot` 提供：`rowsOfLine[line]`、`lineOfRow[row]`、`rowForChar(line, charOffset)`。
- 当语音对齐给出 `AlignResult.anchorToken` 时，用 `anchorLine + anchorCharOffset` 定位段落内字符，再取该偏移所在的视觉行作为滚动目标；篇尾/回退仍以段落为准。

### 3.5 滚动模型

#### 3.5.1 一阶限速跟随（替代弹簧）

```
desired = target - position
step = desired × (1 - exp(-dt / tau))
step = clamp(step, -maxSpeed × dt, maxSpeed × dt)
position += step
```

- 默认 `tau = 70 ms`（`smoothness` 8 映射到 65–76 ms）、`maxSpeed = 1800 px/s`、跳读 `maxSpeed = 3000 px/s`。
- 位移 102 px 时，初始速度约 1450 px/s（未超限），约 210 ms 到 95%；无过冲、无残余速度。
- 目标中途变化时只改 `target`，不重置速度（本来就没有速度状态），不会「追过头再回来」。
- `tau` 映射：`tau = clamp(35, 120, 140 - 8 × smoothness)` ms；`smoothness` 越大越灵敏。
- 静止判据：`|desired| < 0.5 px` 时吸附；连续 3 帧静止后进入 idle，不再请求帧。

#### 3.5.2 小步 vs 大步

| 情况 | 处理 | 时长/速度 |
|---|---|---|
| 目标变化 ≤ 2 个视觉行 | 一阶跟随 | 约 150–240 ms 到 95%，视觉上是「快速滑入」 |
| 目标变化 3–8 行 | 一阶跟随 + 跳读上限 3000 px/s | 约 220–320 ms；不再出现 0.8 s 的追赶 |
| 目标变化 > 8 行（识别跳段） | 直接落位 + 160 ms 交叉淡入 | 不逐行追赶；跳读距离过大时动画会让用户失去位置感 |
| 手动跳段 / 篇首篇尾 / 遥控 jump | 直接落位 + 120 ms 交叉淡入 | 不穿越中间内容；淡入期间旧画面淡出 |
| 拖拽 | 直接跟手，`position += -dy`；松手吸附最近视觉行（阈值 0.35 pitch） | 拖拽时不跑跟随器 |

- 目标去抖保留 60 ms（只对「非跳读」目标生效），避免 ASR 行抖动导致目标来回改；跳读/手动立即提交。
- 不再使用「0.5 行死区」：行目标天然是 pitch 的整数倍，死区只会让小幅修正失效。
- `fastCatchUp` 只控制速度上限与是否跳过去抖，不再改变目标提交方式。

#### 3.5.3 手动与语音的交互

- 拖拽开始：`freeze()`（目标=当前位置），但**不重置** `_anchor`；拖拽中按「带中心最近视觉行」更新 `_anchor`。
- 松手：吸附到最近行顶；如果语音开启，`tracker.forceLine(anchorLine)`、清空闸门，然后恢复目标跟随（不要立刻把位置拉回旧目标）。
- 用户手动滚动后，语音下一次有效匹配才重新接管；避免「松手就被拽回去」。
- 锁定态：手势屏蔽，但语音跟随/手动自动滚动继续（现状保持）。

### 3.6 高亮与预读

- **位置强调，不按身份强调**：对每个可见视觉行计算
  `d = (rowCenter - bandCenter) / pitch`
  `emphasis = clamp(1 - |d| / 0.9, 0, 1)`
  当前带内行 `emphasis=1`，上下相邻行自然衰减。
- 文字颜色：`Color.lerp(dimText, text, emphasis)`；`showNextLine=false` 时把下方衰减半径从 0.9 收紧到 0.55，只保留带内。
- 带本身独立绘制，不随行切换闪烁；行切换只改变各行透明度，且透明度随位置连续变化。
- 语义 `_anchor` 在「行中心越过带中心 ±0.15 pitch」时更新（带滞回），用于遥控、录制、持久化；视觉上不需要等高亮切换。
- 预读：带下方至少保留 2 行（默认 4 行）完整可读；带上方保留 1–2 行帮助回看。底部控制面板淡出后才显示更多行，不改变带位置。

### 3.7 语音跟随的推进与回退

保留现有 `AlignEngine`、`AlignTracker`、`LineStepGate`，但调整接口与节奏：

1. **对齐仍以语义行为单位**：`AlignResult.anchorLine` + `anchorToken`；由 `rowForChar` 映射到视觉行。
2. **提前触发（early arm）**：当当前语义行的 `spokenFraction = (anchorToken - lineStartToken) / lineTokenCount ≥ 0.55`，且 ASR 尾部与下一语义行前 2 个 token 的模糊命中率 ≥ 当前档位阈值 − 0.10 时，允许把目标提前设为下一行（只前进 1 行，不改变回退/跳读规则）。
   - 严格档关闭 early arm；标准档开启；宽松档阈值再降 0.05。
   - 目标提前后，若 250 ms 内没有继续匹配，允许保持（不撤回），避免抖动。
3. **闸门仍是唯一推进权威**：候选行 > 当前行时，按 `maxLeap` 推进；一次推进多个视觉行时只发一个目标，由跟随器一次走完（不排队逐行，避免「连跳」）。
4. **回退**：候选落后 ≤2 行默认保持（口误不回跳）；连续 2 次或 final 才接受，回退动画同样用跟随器，但速度为常态的 0.7 倍，避免「猛回头」。现状闸门会直接拒绝 `candidateLine <= currentLine`，因此新方案需要让闸门输出 `backward` 决策（或把回退判定上移到 tracker，闸门只负责前进），否则回退永远不可达。
   - 证据：`line_step_gate.dart:114-126`。
5. **静音**：2.5 s 无有效识别只更新角标，不冻结已发出的目标；目标完成后停住。5 s 后可选自动暂停（默认关闭），避免长时间静音后突然追一大段。
6. **篇尾**：当目标为最后一个视觉行、位置稳定在 ±1 px 且 `_anchor` 已是最后语义行时，发一次 `finished`：
   - 默认：`paused=true`、状态「已读完」、遥控 `playing=false`、`progress=1`；
   - `endBehavior=loop`：延迟 1.2 s，200 ms 淡出/淡入回到第 0 行，再恢复运行；不滚动穿越全篇。
7. **ASR 缓冲**：保持现有 partial/final 处理；跨行后如果 partial 已包含下一行开头，`AlignEngine` 的窗口天然覆盖，不需要像参照实现那样裁剪 token（我们的窗口是 200 token）。

> 不把小白「0.70 阈值」搬过来的理由：我们的置信度是 DP 代价归一化，分母是最佳路径的 ASR token 数，包含插入/删除惩罚；它的 0.70 是词袋命中率，两者不可比。我们只借用「提前量 + 短位移」的节奏策略。

### 3.8 重排与锚点保持

- 锚点统一存 `AnchorRef { sectionId, charOffset }`（段内字符偏移），而不是行号；行号在快照内是派生值。
- `LayoutSnapshot` 的构建键：
  `(textRevision, stageWidth, fontSize, lineHeight, letterSpacing, fontWeight, textScaler, align, locale)`。
- 重排流程：
  1. 取消当前跟随器动画，记录 `AnchorRef`；
  2. 构建新快照（测量所有语义行，切视觉行，算 tops/pitch/band）；
  3. `newRow = snapshot.rowForChar(anchor.sectionId, anchor.charOffset)`；
  4. `position = target(newRow)`，`_anchor` 更新到对应语义行；直接落位，不做动画；
  5. 重建可见窗口 Widget，替换 `ScriptIndex`/`AlignEngine`；
  6. 语音会话**不停止**：暂停接收更新，换索引，`tracker.forceLine(newLine)`，清空闸门，恢复接收；
  7. 递增 `layoutVersion`，推送遥控/悬浮窗/外接屏。
- 录制不因重排停止；`_stopVoice` 不再级联 `_toggleRecord`。如果当前 ASR 会话不支持热换索引，降级为「暂停对齐 300 ms 后自动重建会话」，但保持录音与麦克风前台服务。
- 重排耗时预算：1000 行以内 ≤16 ms（8 Elite 基准）；超过则在快照构建期间显示上一帧画面 + 100 ms 淡入，不阻塞手势。

### 3.9 悬浮窗与外接屏

- 共享 `ReadingViewport`：
  ```
  layoutVersion, anchorLine, anchorRow,
  windowStart, rows[] (text, scriptLine, rowIndex),
  bandRatio, pitch, rowHeight,
  fontSize, mirrored, theme
  ```
- 主页面渲染完整快照；悬浮窗/外接屏只需要「窗口切片 + 带位置」，不重新排版。
- 悬浮窗 3/5 行：`windowStart = clamp(anchorRow - floor(count/2), 0, totalRows - count)`；已实现为按锚点重算窗口切片并自动跟随，换窗目前是直接替换（未做 120–160 ms 滑动动画，列入真机验收项）。
- 悬浮窗全稿模式（`lineCount=0`）：已下线；旧配置在 `OverlaySettings.normalized()` 中迁移为 5 行窗口，设置面板不再提供「全稿」。
- 外接屏：继续 5 行、锚点居中、原生 `TextView` 渲染；已增加可选 `bandRatio` 参数，默认 0.5（居中），Kotlin 侧按 `(bandRatio - 0.5) × 容器高度` 平移，缺失时保持居中。
- 镜像：悬浮窗/外接屏只支持水平镜像（现状）；垂直镜像与分光镜校准只在主页面生效，文档写清差异。

### 3.10 三端差异与降级

| 端/场景 | 能力 | 降级路径 |
|---|---|---|
| Android 主页面 | 固定带、跟随器、镜像/分光镜、重排热换索引 | 快照构建超时 → 保留旧快照 + 提示，不阻塞输入 |
| Android 悬浮窗 | 窗口切片、带居中、滑动换窗 | 主引擎后台无帧 → 保留最后窗口，不尝试动画 |
| Android 外接屏 | 5 行居中、水平镜像 | 原生不支持新参数 → 忽略 `bandRatio`，保持居中 |
| iOS | 主页面同模型；无系统悬浮窗/外接屏 | 只保留应用内阅读 |
| macOS/Windows | 主页面同模型；窗口缩放触发快照重建；键盘/触控板滚动吸附 | 无系统悬浮窗；外接屏未实现 |
| 测量不可用/异常 | `TextMeasurer` 失败 → 回退 `LineFit` 估算行高，视觉行=语义行 | 保证可读，几何精度下降并在日志标注 |

---

## 4. 参数表（可落地默认值与范围）

| 参数 | 默认 | 范围 | 归属 | 说明 |
|---|---|---|---|---|
| `bandRatio` | 0.34 | 0.22–0.60 | 阅读预设 | 复用 `readAheadRatio` 键，语义改为「当前行中心在可用高度的比例」 |
| `rowPadY` | 0.08 × fontSize | 0.04–0.16 em | 排版 | 带上下内边距 |
| `rowGap` | 0.10 × fontSize | 0.04–0.30 em | 排版 | 视觉行间距；旧预设按旧公式回填 |
| `lineHeight`（新语义） | 1.55 | 1.0–2.5 | 阅读预设 | 可选「紧凑/标准/宽松」1.45/1.55/1.75 |
| `pitch` | 派生 | — | 快照 | `textHeight + 2×rowPadY + rowGap` |
| `bandHeight` | = rowHeight | — | 快照 | 单行视觉行高度 |
| `minRowsAbove` | 1 | 1–2 | 布局夹取 | 带上方至少 1 行 |
| `minRowsBelow` | 2 | 2–4 | 布局夹取 | 带下方至少 2 行 |
| `tau` | 70 ms | 35–120 ms | 行为 | 由 `smoothness` 映射 |
| `maxSpeed` | 1800 px/s | 1200–2400 | 行为 | 常态跟随 |
| `catchUpSpeed` | 3000 px/s | 2400–4000 | 行为 | 跳读 |
| `targetDebounce` | 60 ms | 40–100 | 行为 | 非跳读目标 |
| `settleEpsilon` | 0.5 px | 0.2–1.0 | 行为 | 吸附阈值 |
| `jumpFade` | 120 ms | 80–160 | 行为 | 跳段交叉淡入 |
| `overlaySlide` | 140 ms | 100–180 | 悬浮窗 | 换窗滑动 |
| `earlyArmFraction` | 0.55 | 0.45–0.7 | 语音 | 当前行已读比例 |
| `earlyArmTokens` | 2 | 1–3 | 语音 | 下一行前缀 token |
| `earlyArmMargin` | 0.10 | 0.05–0.15 | 语音 | 阈值放宽量 |
| `silenceToast` | 2.5 s | 1.5–4 | 语音 | 角标「未检测到语音」 |
| `autoPauseSilence` | 关闭 | 5–30 s / 关闭 | 语音 | 长时间静音自动暂停 |
| `endBehavior` | `stop` | `stop`/`loop` | 阅读预设 | 篇尾行为 |
| `loopDelay` | 1.2 s | 0.6–2.0 | 阅读预设 | 循环延迟 |
| `layoutBudget` | 16 ms | — | 性能 | 快照构建上限 |
| `windowRenderMargin` | 2 行 | 1–4 | 渲染 | 可视窗口上下多渲染的行数 |

> 现有参数兼容：`readAheadRatio` 键保留；`smoothness` 保留但映射到 `tau`；`lineStepFollow` 保留（true=闸门切行，false=每次更新都更新目标）；`speed` 仅影响手动模式（行/秒 → 视觉行/秒）。

---

## 5. 迁移与兼容

### 5.1 预设

- `readAheadRatio` 0.2–0.6 直接沿用，解释变化；旧值 0.35 落在新默认附近，不需要迁移。
- `smoothness` 4–12 沿用；新映射 `tau = clamp(35, 120, 140 - 8×smoothness)`，旧值 8 → 76 ms，手感接近但无过冲。
- 新增 `rowGap`、`endBehavior`、`autoPauseSilence`；旧 JSON 缺失时用默认值，`fromJson` 不抛异常。
- `lineHeight` 若采纳新语义（pitch 倍数），旧预设按 `oldPitch/fontSize` 回填并夹取；用户重新保存后写新值。不能静默把所有用户排版变紧。
- `maxLineChars` 已废弃（0.18.0），继续忽略。

### 5.2 `layoutVersion` 与遥控

- `layoutVersion` 继续在每次快照重建时递增；v1 字段 `anchorLine`、`lineCount`、`anchorText` 的含义不变（仍为语义行）。
- **v1 不发生 breaking change**：视觉行只在本机内部使用；`next_line/prev_line` 仍按语义行 ±1；遥控端不感知 pitch。
- 可选 v2 增量字段（向后兼容，旧端忽略）：`rowHeight`（视觉行高）、`rowCount`（视觉行总数）、`bandRatio`（阅读带位置）、`typographyModel`（`1` 旧 / `2` 紧凑）。
  - 实现未加 `anchorRow` 与 `layoutModel` 两个设计稿字段：`anchorLine` 已足够驱动遥控端文本定位，排版模型用 `typographyModel` 表达更直接。
- 旧遥控端只读 `anchorLine/layoutVersion`，仍能正确高亮文本；`layoutVersion` 变化时丢弃文本缓存的行为保持不变。

### 5.3 悬浮窗/外接屏协议

- 悬浮窗 `init/state/anchor` 消息增加可选 `layoutVersion`、`bandRatio`、`rowHeight`、`typographyModel`；旧字段 `lines/anchor` 保留，旧悬浮窗忽略新字段仍能显示。`windowStart` 由浮窗自行按锚点计算，未新增协议字段。
- 外接屏 `present/update` 增加可选 `bandRatio`；原生 `call.argument` 缺失时用 0.5 并夹取到 0.2–0.8，旧版本不受影响。
- 全稿模式下线已完成：`OverlaySettings.lineCount=0` 迁移为 5，设置页不再展示该选项。

### 5.4 录制/回放/断点

- 断点 `saveAnchor(documentId, anchorLine)` 仍存语义行；新快照加载后 `rowForLine` 映射到视觉行。
- 录制时间轴使用语义行号；回放时按语义行跳转，再映射视觉行，不需要重录。
- 分光镜/镜像预设不变；新增校准卡只读写 `prismDy/bandRatio`。

### 5.5 风险与 breaking 评估

| 变更 | 是否 breaking | 说明 |
|---|---|---|
| 固定阅读带 + 位置强调 | 视觉 breaking，不涉及数据 | 需要产品/用户确认；建议保留一个版本的「经典高亮」开关作为回退 |
| 视觉行作为滚动单位 | 内部 breaking | `ScrollPlanner` 契约变化；遥控/存储仍用语义行，外部无感 |
| `lineHeight` 语义调整 | 预设观感 breaking | 必须做旧值回填，且默认只对新安装生效 |
| 重排不停麦 | 行为改善，非 breaking | 需要拆分会话与对齐流水线；失败时降级为自动重启 |
| 遥控 v2 字段 | 非 breaking | 纯增量 |
| 悬浮窗全稿模式下线 | 功能 breaking | 需要产品确认；备选是保留但改为自动跟随 |

---

## 6. 对测试与文档的影响

### 6.1 测试

新增（纯 Dart 优先，`TextMeasurer` 接口注入 fake）：

- `core_reader_layout`：视觉行切分（单行/折行/空行）、`pitch`/`tops`、`rowForChar`、`rowForLine`、镜像/分光镜目标公式、边界夹取。
- `ReadingFollower`：102 px 阶跃 95% 时间、无过冲、速度上限、目标中途变化、冻结/恢复、跳读。
- `BandEmphasis`：`emphasis` 随位置连续变化、`showNextLine=false` 的衰减、标记词颜色继承。
- `AnchorMapper`：字号/宽度/旋转重排后字符偏移保持；跨段边界；末行。
- `EndDetector`：末行稳定、`stop`/`loop`、遥控 `progress=1`。
- `ReflowPipeline`：重排期间不停止录音、语音索引热换、闸门重置。
- 悬浮窗窗口切片/滑动、外接屏参数默认值。

需要修改的现有测试：

- `apps/app/test/reader_page_test.dart`、`reader_page_interaction_test.dart`：35% 占位/行高亮断言改为带位置与视觉行断言。
- `packages/core_scroll/test/scroll_planner_test.dart`：若 `ScrollPlanner` 被 `ReadingFollower` 替代，测试迁移/删除；不要保留两套滚动器。
- `apps/app/test/overlay_app_test.dart`、`external_display_test.dart`：新增窗口/带字段与兼容路径。
- `apps/app/test/remote_protocol_test.dart`：v2 可选字段与旧帧兼容。

覆盖率：新增几何/跟随/映射逻辑应达到项目 70% 门槛；`TextPainter` 适配层通过 fake measurer 覆盖分支，真机测量单独列入设备验收。

### 6.2 文档

- 本文件：新增设计稿。
- `docs/design/20261106-reader-state-machine.md`：
  - §1 起始态、§2 逐行跟随、§3 角标位置（35% 表述改为带位置）；
  - §6 语音匹配档位（增加 early arm、篇尾、重排热换索引）；
  - §7 自动每行字数（明确「语义切分」与「视觉行测量」的分工）。
- `docs/design/20261106-overlay-window.md`：§4 状态机、§5 尺寸/坐标（窗口切片、带位置）、§6 已知限制（全稿模式）。
- `docs/api/remote-protocol.md`：新增 §2.2 的 v2 可选字段与兼容说明；`anchorLine` 语义不变。
- `docs/help/`：用户手册增加「阅读线位置」「跟随灵敏度」「篇尾行为」「分光镜校准卡」；说明固定阅读带与旧版高亮的差异。
- `docs/README.md`：设计索引新增本文件。
- 实现阶段再更新 `CHANGELOG`、测试记录（新 `docs/testing/records/`）与版本号；本轮不动。

### 6.3 ADR

- 新增 `docs/architecture/adr/0006-reading-window-and-visual-row-model.md`（Proposed）：固定阅读带、视觉行坐标、语义行/视觉行分离、一阶限速跟随、三端共享 `ReadingViewport`。
- 无需作废现有 ADR：
  - `0004` 是「嵌入字体/包体」，与排版模型无关；
  - `0005` 是性能基准，本方案沿用骁龙 8 Elite；
  - `0002` ASR 引擎不变。
- 若最终决定用视觉行替代 `ScrollPlanner` 的公开契约，在 ADR-0006 的「影响」里记录「`ScrollPlanner` 的 35% 注释与 `readAheadRatio` 字段废弃」。

---

## 7. 风险与待拍板项

1. **视觉语言变化**：固定带 + 位置强调会让高亮不再「跟着行走」，老用户可能一开始不习惯。
   - 建议：默认新方案，保留一个版本的「经典高亮」开关（只改渲染，不改坐标），下个大版本移除。
2. **排版默认值**：是否把 `lineHeight` 从 2.05 倍收紧到 1.55 倍。
   - 建议：新安装用 1.55，旧预设回填旧值；设置页给「紧凑/标准/宽松」三档。
3. **重排是否停麦**：热换索引需要拆 `VoiceFollowSession` 的音频与对齐职责，工作量大于滚动本身。
   - 建议：分两阶段；先保证录音不断，语音允许 300 ms 自动重启；再做真正热换。
4. **篇尾默认**：停止还是循环。
   - 建议：默认停止，循环作为设置项；循环用淡入淡出，不穿越全文。
5. **悬浮窗全稿模式**：下线还是改为自动跟随。
   - 建议：改为固定 5 行窗口化；全稿在 200–600 dp 宽的小窗里不可读。
6. **遥控 v2**：现在加可选字段，还是等视觉行稳定后再加。
   - 建议：先加 `layoutModel/anchorRow/rowCount/bandRatio` 可选字段，不改 v1 语义。
7. **视觉行与语义行的映射成本**：`TextPainter.computeLineMetrics()` 在 1000 行台本上的耗时需实测；若超过 16 ms，快照构建要分片/缓存。

---

## 8. 验证计划（实现后如何证伪）

1. **纯单元/Widget**：§6.1 全部测试 + 现有四检（format、`dart analyze --fatal-infos --fatal-warnings`、`check_imports`、`flutter test --coverage`）。
2. **回放音频**：用现有 `demo_zh.wav` 和录制回放，测 0.8×/1.0×/1.3× 语速下的目标延迟、切行次数、错误前进/回退。
3. **真机场景**：旋转、分屏、折叠屏展开、字号 24/44/160、系统字体缩放 1.0/1.3/2.0、四组镜像、`prismDx/Dy ±0.05`、30 分钟长稿、跳段、篇尾/循环、悬浮窗 3/5 行、外接屏插拔。
4. **指标**：
   - 带内行中心误差 ≤2 px（静止）；
   - 单行目标 95% 到位 ≤240 ms；
   - 无过冲（位移曲线不反向超过 0.5 px）；
   - 快照构建 p95 ≤16 ms（1000 行）；
   - 语音切行延迟（说出下一行首字 → 目标开始移动）≤300 ms；
   - 误前进率不高于现有标准档（同一回放集）。
5. **未验证声明**：本文件所有「体感」结论（节奏、跟手、视觉舒适度）均为设计推断，必须按上面场景做真机 A/B 后才能作为验收依据；本轮的「事实」仅限代码与反编译可见行为。

---

## 附录 A：现状关键证据索引

| 结论 | 代码位置 |
|---|---|
| 语义行按句末/逗号切分 | `packages/core_models/lib/src/script_model.dart:24-110` |
| 自动每行字数估算 | `packages/core_models/lib/src/line_fit.dart:52-67` |
| 每次 build 全量 TextPainter | `apps/app/lib/features/reader/reader_page.dart:1036-1063` |
| 顶部 35% 占位 | `apps/app/lib/features/reader/reader_page.dart:1160` |
| 行号身份高亮 | `apps/app/lib/features/reader/reader_page.dart:1171-1204` |
| 弹簧参数/去抖/死区 | `packages/core_scroll/lib/src/scroll_planner.dart:10-17、89-103、143-173` |
| 行距估算 vs 实测 | `reader_page.dart:1042-1043、1049-1062`；`reader_settings.dart:221-223` |
| 每次 partial 都 setState | `reader_page.dart:2425-2432` |
| 重排停麦/重建 tracker | `reader_page.dart:1016-1034、238-270` |
| 停麦级联停录制 | `reader_page.dart:2382-2407` |
| 三层阈值 | `core_alignment/lib/src/aligner.dart:117-219`、`tracker.dart:131-159`、`line_step_gate.dart:99-198` |
| 悬浮窗居中窗口/全稿不跟随 | `overlay_app.dart:370-419` |
| 外接屏 5 行居中 | `ExternalDisplayController.kt:181-208` |

## 附录 B：小白关键证据索引

| 机制 | 位置 |
|---|---|
| 行顶/行高/最近行/行目标 | `XBPrompterLayout.java:705-708、741-748、989-1017` |
| 焦点行默认 100 dp | `PrompterHelper.java:223` |
| 焦点框高度跟随行高 | `XBPrompterLayout.java:780-783` |
| TextView paddingTop/paddingBottom | `XBPrompterLayout.java:1616`；`PrompterActivity.java:449-464` |
| 文字大小 28sp / 对齐 / 镜像 | `XBPrompterLayout.java:1594、1636-1656`；`PrompterHelper.java:82、85` |
| ≤2 行小步 / >2 行平滑跳转 | `XBPrompterLayout.java:640-682`；`XBTextScrollView.java:317-320` |
| 小步速度 5 ms × 1–6 px | `XBTextScrollView.java:279-305` |
| 自动滚动 31 档 | `XBTextScrollView.java:39-42、446-457`；`PrompterHelper.java:78` |
| 手动静止 60 ms 后吸附 | `XBTextScrollView.java:234-271` |
| 阈值 0.55+0.05×gain（默认 3） | `AIPrompterWrapper.java:199-210`；`PrompterHelper.java:203` |
| 下一行前缀/前看 skipLine（默认 3） | `AIPrompterWrapper.java:204-240`；`PrompterHelper.java:204` |
| 末行停止/循环 | `XBPrompterLayout.java:683-690`；`XBTextScrollView.java:217-229` |
| 拼音混淆表 | `XBPrompterUtils.java:37-110` |

---

## 附录 C：一页纸决策卡

- **保留**：语义行、`ScriptModel` 断行、`AlignEngine`、三档 `MatchProfile`、`layoutVersion`、v1 遥控字段。
- **替换**：`ScrollPlanner` 二阶弹簧 → 一阶限速跟随；`readAheadRatio` 占位 → 显式带坐标；行号高亮 → 位置强调。
- **新增**：`LayoutSnapshot`/`VisualRow`、`AnchorRef`、`ReadingViewport`、early arm、篇尾状态、校准卡、重排热换索引。
- **不做**：不改 ASR 引擎、不改版本号、不把小白阈值直接搬过来、不在本轮实现代码。
