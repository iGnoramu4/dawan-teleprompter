# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与 SemVer。

## [0.28.3] - 2026-11-12

> 已出 release：`dist/teleprompter-0.28.3-android.apk`（396,865,491 B，
> SHA256 `59f0e6be803c573ba6e133da4c2d6696c7eddb9a525e393cb60623f8c2fdd0e0`）。
> 发布说明见 `docs/releases/0.28.3.md`；已知问题以该文为准。

### Fixed

- **语音跟随「位置锁死 / 抢跑」**（0.28.3+2037）：
  - 对齐窗口起点改为**页面锚点**（`anchorCharLine`）而不是跟踪器行号；跟踪器失步时窗口不再一起错位。
  - 手动拖动/甩动、手动跳行、回到篇首时同步 `AlignTracker.forceLine(_anchor)`，并重置闸门/覆盖率/early-arm/跳行预算；`AlignTracker.reset()` 一并清掉 `_line`。
  - 短跨度/次高置信不再跨行：`span < 6` 或 `conf < 0.8` 时单次只允许 +1 行（跟踪器、闸门、覆盖率、重定位四条通道统一）。
  - 回放路径音频结束后补 600 ms 尾音再 flush，减少结尾短句整句丢失；麦克风实时路径不加假 final。
  - 移除 `diag/voice` 中的识别原文（CODING §7），只保留计数/行号/置信度。

### Changed

- **提词滚动拆成两条路径**（随 0.28.3 发布）：
  - 语音跟随：目标为**整视觉行**，第一行用 `easeOutCubic` 500 ms 吸附到阅读带下划线（平滑度 4–12 映射 550/500/450 ms/行），单段最多 1 行，段末速度为 0。行内字符推进不产生亚行位移。
  - 跨多行追赶：同一段连续吸附里，从第 2 行起每行 **160 ms**，不再让 500 ms 线性叠加。2 行 660 ms、3 行 820 ms；追加行仍是独立的一段 easeOutCubic、仍逐个视觉行落位。取舍：只有单行事件保留完整 500 ms 节奏，追加行明显更快；这样读快时不会越落越远，也避免「一次滑很远」。
  - 触控：拖拽/惯性仍直接改连续像素位置，不做整行量化、不落位；识别暂停或关闭时冻结跟随器，正在进行的吸附立即取消，拖动与甩动完全不受语音目标影响。
- 松手惯性、拖拽结束逻辑保持不变；未恢复「松手跳整行」，也未把 `anchorRow` 加回舞台缓存键。
- 延迟补偿估计仍写入 `voice/latency_compensation`，但不再以分数行前馈滚动目标（整行吸附下分数前馈会破坏「行落到下划线」）。

### 测试与工程

- 新增/更新 `core_reader_layout` 单测：单行 500 ms 内到位且前快后慢、同目标重复更新不重启动画、首行 500 ms + 追加行 160 ms（跨 3 行共 820 ms）、每段位移 ≤1 行、冻结取消吸附、拖拽/惯性取消吸附、吸附完成后下一事件重新按 500 ms、平滑度映射时长。
- 真机 debug（f37aa514，0.28.2+2036，平滑度 8.0）语音朗读 70 s 整段：从 1/30 推进到 30/30（末行「谢谢大家。」落到下划线），无跳过；全程单行吸附实测 492–508 ms。跨行实测：2 行 672 ms、3 行 826/834 ms、4 段 1005 ms（= 500 + (n−1)×160，含帧对齐误差）。帧汇总 3607 帧，jank 4（0.11%），P95 build 1.27 / raster 5.61 / total 8.89 ms。
- 说明：同音频加速到 49.6 s 时识别器在第 8 行后 `matched=false`（低置信），页面停在已识别行不动；换 70 s 语速后完整跟到末行。该停顿是识别/匹配丢失，不是滚动落后（滚动目标始终等于已识别行）。（2026-11-12 诊断修正：根因是页面锚点 / 跟踪器 / 对齐窗口三者失步后无法自愈，见上方 Fixed。）
- 触控回归：暂停态（语音仍在识别）播放音频并快拖/甩动，只有 1 段连续位移，停稳后 4 s 画面 diff = 0.0；无任何吸回。
- 证据：`build/shots/voice500-0282.mp4`、`voice500b-0282.mp4`、`voice500_multi_0282.mp4`、`paused500-0282.mp4`。

### 红线

- 闸门与预算未改动。单次 ≤3 行、任意 10 秒 ≤3 行、误触发 0；包与 app 测试全过。

## [0.28.1] - 2026-11-11

> 本版是 0.28.0 之后的首个发布包，包含 0.28.0 的全部改动（五档宽松度、移除台本段落、默认中文轻量 14M、左右边距独立、提词页单栏功能栏）与本次滚动改造。

### Fixed

- **提词页整行吸附**：三处按整行落位的逻辑全部移除——手动松手后的 `jumpTo(整行)`、语音目标只取 `rowForChar` 整行、舞台缓存键包含 `anchorRow` 导致每跨一行重建整篇。现在松手停在哪一行就停在哪一行，不再吸到行边界。
- **滚动卡顿/顿挫**：跟随目标改为分数行位置（`rowPositionForChar` = 行号 + 行内字符进度），滚动位置是连续像素量；视觉上不再出现「攒够一行再跳」的台阶。
- **追赶限速刹车**：删除常态/追赶两档速度，统一单档 2400 px/s，避免「先快后顿」和追上目标时的速度回落。
- **手动滚动无惯性**：新增 `fling(velocity)`，松手后按 450 ms 时间常数指数衰减，触边即停；暂停、回退去抖与拖拽结束不再把位置拽回行边界。

### Changed

- 跟随、手动匀速、语音推进三条路径共用同一个 `ReadingFollower`（一阶指数逼近，tau=70 ms），渲染仍只有一处 `Transform.translate`。
- 只有显式跳转或目标距离超过 8 行才直接落位并做 120 ms 淡入，常规跟随与拖拽不做任何行量化。

### 红线

- 跳读红线未改动。10 段合成语料复测：误触发 0，`maxSingleLeapLines = 0`、`maxLeapLinesPer10s = 0`、`totalLeapLines = 0`。

### 测试与工程

- 真机 debug（f37aa514）应用内 `FrameTiming` 插桩对照：拖动会话 janky 9→5（0.25%→0.14%）、p95 total 6.59→6.60 ms；手动匀速 janky 23→7（0.73%→0.19%）、p95 total 8.92→9.55 ms；松手惯性 janky 8（0.22%）、p95 total 8.99 ms；语音跟随 janky 12（0.33%）、p95 total 6.41 ms。全部低于 16.7 ms 预算。
- 逐帧抽图同口径对照：改前 `build/shots/drag-before2.mp4` 在松手处出现 1 次 **81 px** 落位跳变（随后静止），即吸附；改后 `build/shots/slow-drag-after.mp4`（453/454 帧有位移）每帧位移 1–3 px、最大 11 px，0 次吸附跳变。`fling-after2.mp4` 显示惯性速度从约 23 px/帧单调衰减到 0；`voice-follow-after2.mp4`（156/158 帧有位移，中位 2 px/帧）同样 0 次吸附，日志中 `line 0→1`、`confidence 1.0`、`line_coverage ratio 1.0`。
- 新增/更新单测：分数行目标、单档限速、松手惯性、触边即停、`rowPositionForChar` 连续推进。
- `dart format`、`dart analyze --fatal-infos --fatal-warnings`、`check_imports`、`license_scan` 全过；app 与 `core_reader_layout` 测试通过，`core_reader_layout` 行覆盖 100% / 88.2% / 92.6%。

### 发布

- 产物：`dist/teleprompter-0.28.1-android.apk`，396,865,491 B，SHA256 `5decaf969b2ff978a176dd11ae25f8bf1275674ac7a8bcb4dd26265fb88ebd5f`；`dist/SHA256SUMS` 已追加并通过 `shasum -a 256 -c`。
- 构建前 format 158 文件 0 变更，构建后未再改动手写 Dart；`libapp.so` 可检出 `rowPositionForChar`、`targetForRowPositionWithMirror`、`_buildBandUnderline`、`_advanceTo`、`_onDragEnd`，确认新滚动代码进包。
- 真机（f37aa514）从 0.27.2 覆盖安装到 0.28.1：`install -r` 成功、未卸载；`versionName=0.28.1`、`versionCode=2034`；首页 3 个台本与「上次」时间保持不变；冷启动正常，logcat 无 FATAL/ANR。
- 发布说明：`docs/releases/0.28.1.md`；索引：`docs/releases/README.md`。本版仍为 Android Debug 签名，真人语料未建立，`veryLoose` 档自动跳读上限仍为 3 行。

## [0.28.0] - 2026-11-11

### Changed

- **识别宽松度改为 5 档**：`veryStrict / strict / standard / loose / veryLoose`，设置面板只显示档位名称与一句用途说明，不再展示阈值、确认次数、前看行数等参数。旧三档名称（`strict/standard/loose`）仍是新五档中的合法值；其余旧值按默认档处理，不报错。
- **彻底移除台本段落**：新建、编辑、导入都只产生一整段连续正文，编辑器只有一个正文输入框与全文绝对偏移的标记。存储仍保留一行 section 承载全文，`rawText` 是唯一正文来源；断点、标记、录制时间轴统一使用全文偏移。旧的多段 `.tps` 包按「不兼容」处理并提示重新导入，不会写入半截数据。
- **默认识别模型切回中文轻量 14M**：`bilingual-mixed`（约 209 MB）仍可在设置里选用。开箱不再支持中英混说。
- **左右边距分别设置**：原「水平边距」拆成左边距、右边距两个独立持久化项；舞台宽度按两侧实际可用宽度计算，超过 980 px 时居中。
- **提词页功能栏单栏化**：移除顶部栏与识别参数面板，默认只展示上一行/播放暂停/下一行/麦克风。设置页新增「功能栏按钮」多选，其余能力收进阅读设置；手动隐藏/唤出与状态持久化保留。识别健康状态只通过麦克风角标表达。

### 红线

- 跳读红线未改动：单次自动前进 ≤3 行、任意 10 秒累计 ≤3 行、误触发 0。10 段合成语料复测：误触发 0，`maxSingleLeapLines = 0`、`maxLeapLinesPer10s = 0`、`totalLeapLines = 0`。

### 测试与工程

- 同环境（arm64 宿主 / 14M 模型 / 10 段合成语料）评测：CER 11.6%、命中率 100%、跟随延迟 P95 1626 ms、首字延迟 P95 780 ms、误触发 0、RTF 0.0124。
- `dart format` 158 文件 0 变更；`dart analyze --fatal-infos --fatal-warnings` 应用与 9 个本地包全部无问题；`check_imports` OK；app 与 packages 测试、`tool/eval` 全过。

### 兼容性

- 不兼容 0.27.x 的旧台本分段数据、旧三档宽松度语义、旧单一边距与旧断点坐标；遇到无法读取的旧数据时按「不兼容」提示，不崩溃、不留半截状态。应用内新格式自身导出再导入内容一致。

## [0.27.2] - 2026-11-11

### Fixed

- 长分句对齐窗口（zh_fast P50 2220 ms 的根因）：ASR 文本是「本分句累积」，端点前不断在尾部追加。窗口若跟随阅读位置滑动，文本前缀就落在窗口之前、只能记作插入代价；一条分句超过带宽 40 音节（约 8 s 快速朗读）后，真实路径落到 `|i-j| <= band` 之外，DP 改走「删台本前缀 + 把文本尾巴对到更后面」的假路径，锚点在 8.1 s 起连锁前跳（1→2→3）、置信掉到 0.19–0.31、滚行冻结，直到 21.5 s 端点出现新分句才追回。现在窗口起点取**分句起点**（端点、或文本公共前缀骤降即重设；阅读位置远超「分句起点 + 文本长度」可解释范围时作废旧起点），DP 首行台本前缀免费跳过，窗口长度自适应 `max(windowW, m + 2 * band)`（上限 600）——带宽只约束分句内部的局部错位，不再限制分句长度。

### Added

- `AlignMetrics` 对齐性能计数（默认关闭，评测打开）：DP 次数/格数/微秒、预筛额外 DP 次数、重锚扫描与 DP 次数，随评测报告写入 `latencyBudget`。

### Changed

- 阅读页舞台子树缓存：partial 更新仍逐条 `setState`，但正文只依赖「排版快照 + 当前视觉行 + 主题/对齐/标记数/滚动带位置」；键不变时返回同一 Widget 实例，Flutter `updateChild` 直接跳过整棵子树 update，不再每次 partial 重复布局与光栅。

### 性能（同环境、同语料、同模型、同档位：宿主机 arm64 / 10 段 246.5 s / zipformer-zh-14M-int8）

- 端到端延迟预算（P50 / P95）：采集分片固定 20 ms（宿主）/ 80 ms（真机），真机音频线程 `backlogMs = 0`（无排队）；解码 0.2 ms / 3.2 ms（宿主，max 6.3 ms，RTF 1.14%，`decode` 762 次对 12329 个分片，`isReady` 门控、无重复喂入），真机 `decodeMs` 1–20 ms/分片、RTF 8.6–9.3%；ASR 出字间隔 320 ms / 1280 ms（max 1920 ms）；对齐 DP 58 µs / 384 µs（984 格/次，≈1 次 DP/partial）；界面重绘真机帧耗时 build 0.42 / 0.81 ms、raster 2.71 / 4.48 ms、`totalSpan` p95 7.07 ms（3667 帧，janky 8 帧，0.27.0 装机实测存档）。**最大项是模型 chunk 决定的出字节奏，不是算力**：解码 + DP + 重绘合计不足端到端时间的 2%。
- zh_fast 单段：P50 2220 → 880 ms、P95 6454 → 1010 ms、命中 80% → 100%。
- 10 段汇总：命中 97.4% → 100%、P50 1032 → 925 ms、P95 2854 → 1626 ms、均值 1250 → 938 ms，误触发 0。
- 线程数 `--threads 2` 对照：RTF 1.18% → 0.99%（−15%），跟随延迟 P50/P95 与 zh_fast 完全不变 → 不改默认（单线程省电）。
- bilingual 209 MB 模型：解码只占 RTF 1.2%，换小模型对延迟无收益，且会丢中英混说，**不换**。

### 红线

- 误触发 0；单次跳读 `maxSingleLeapLines = 0`、任意 10 s 累计跳行 `maxLeapLinesPer10s = 0`、全程 `totalLeapLines = 0`（10 段全量）。

### 测试与工程

- core 124 项（新增「单条长分句（超过带宽 40 音节）仍能对齐到已说位置」）、app 212 项、eval 5 项全部通过；`dart analyze` 三包无问题、`dart format` 113 文件 0 变更、`check_imports` OK、覆盖率 78.4%（阈值 ≥70%，未下调）。
- 真实录音语料仍为空：本轮所有数字均来自合成语料，只代表时序与对齐链路，未据此下任何识别质量结论。

### 构建产物

- release 包在格式化收敛后的源码上构建（`dart format --set-exit-if-changed` 0 变更后才开始构建；`app.so` 编译于 14:30，`strings` 可见 `_commonPrefix`、`_runDpInner`、`_buildStageUncached`，确认修复已进包）。
- 路径：`dist/teleprompter-0.27.2-android.apk`；字节数 397,045,635；SHA256 `bb1382815e5701034400db998340d234233f8ae645cf2bea847ca6204b3aac55`。
- 版本：`versionName=0.27.2`、`versionCode=2032`、`minSdk=24`、`targetSdk=36`、包名 `com.dawan.teleprompter`、启动器名「大皖提词器」。
- 签名：APK Signature Scheme v2（v1/v3/v3.1/v4 未启用），Android Debug 证书（`C=US, O=Android, CN=Android Debug`，证书 SHA-256 `249f4471…9546183`），仅供测试安装，不用于商店分发。
- 体积：相对 0.27.0（396,947,331 B）增加 98,304 B（+0.02%）；与 0.27.1 构建（397,045,635 B）持平。
- `dist/SHA256SUMS` 追加本版一行，历史条目保留，`shasum -a 256 -c` 4 行全部 OK。

## [0.27.1] - 2026-11-11

### Fixed

- 跳读棘轮：跟踪器行号可能先于阅读位置前进，阅读页仍回填上一行的字符偏移，`tokenAtOrAfter` 越界时返回下一行行首，对齐窗口整体越过当前行，DP 只能去更后面找词，形成「低置信但一直往前跳」（实测可复现 `1→2→3` 连锁）。现在越界偏移按过期处理、退回当前行行首；`voice_follow` 仅在「偏移所属行 == 跟踪器行」时使用偏移。
- 解耦展示与跟随：对齐未命中/等待时仍刷新识别文本、解码耗时与心跳，只冻结滚行；`AlignResult` 新增 `matched/pending/reanchored/suggestedLine`。
- 端点后少于 3 个音节记为「等待」，不再当作零证据计入弱命中与降级计数。
- 采集/引擎死亡自动重建：引擎、音频采集的启停都带超时与冷却重试，watchdog 可识别引擎停滞并重启，不再静默冻结。

### Added

- 失败重定位：连续 3 次未命中后用当前 partial 在更大范围重锚；只前进、落点超过当前行 +3 时只更新 `suggestedLine` 不改位置；除单次高置信（≥0.8）外同一落点需连续两次确认；重锚后需先出现 3 次正常命中才允许下一次重锚。
- 预筛接管收紧为「自身置信 ≥0.5 且比锚点结果高 ≥0.2」，避免 +0.1 优势驱动的低置信连锁前跳。
- 累计跳行预算 `AutoAdvanceBudget`：任意 10 s 内跳行总和不超过 3 行，用尽后只允许逐行推进；在所有自动推进的唯一入口（阅读页 `_advanceTo`、评测 `FollowSimulator._advance`）统一夹一次，防止单步 3 行连续叠加成十行以上的累计跳读。逐行推进不计入预算，正常朗读不会因此卡住。

### 测试与工程

- core 123 项、app 212 项、eval 5 项全部通过；新增「连续多次 3 行跳不累积」「窗口滚过后重新放行」「逐行推进不计入预算」「跨行后沿用旧字符偏移不越窗」「卡住后重锚」「重锚永不超 3 行」「漂移候选每次最多 +1」等用例。
- 同环境同语料同模型（宿主机 arm64、10 段、zipformer-zh-14M-int8）严格 A/B：把本版四项保护逐项回退得到的同管线改前为命中 92.3% / P50 925 / P95 7860 / 均值 2054 ms，本版为 97.4% / 1032 / 2854 / 1250 ms；CER 11.6% 持平，误触发 0、最大抢行 0 行。
- 存档参考：`build/eval-027-legacy.json`（2026-11-11 00:30）记录 100% / 877 / 1626 ms，但它与当前 `AlignEngine` 跟随链路不同——同样的识别文本、同样 4 次跨行，legacy 在 605/801 ms 切行；逐项回退本轮改动都复现不出该数值。因此该文件只作为上一轮记录，不作为本版 A/B 基线，也不用于衬托提升。
- 覆盖率 76.3%（阈值 ≥70%，未下调）；`dart analyze` 三包无问题、`dart format` 0 变更、`check_imports` OK。

## [0.27.0] - 2026-11-11

### Changed

- 语音匹配**只有读音一个口径**：删除「按读音近似匹配」开关、文字逐字匹配分支与死代码；旧预设中的 `phoneticMatch`/`matchMode` 读入忽略、写回不再输出。
- 模糊音扩充：在 `zh/ch/sh → z/c/s`、`n/l`、前后鼻音之外纳入 `f/h`、`r/l` 与 `uang/uan`、`iang/ian`、`ing/in`、`eng/en`、`ang/an`、`iu/ou`；新增音节级近似（声母相同、编辑距离 ≤1），容忍少量漏读/多读。
- 判定单位从「逐个文字命中」改为**整行读音覆盖度**：按语义行的有效音节算覆盖率，按行长分档（≤5 → 0.9、≤12 → 0.8、≤25 → 0.72、>25 → 0.65），并要求最远命中落在本行 60% 之后、行内单调前进；达标后不再要求逐字连续命中与弱命中累计。行内字符锚点仍用于坐标、进度与录制时间轴，但不再参与放行。
- 连续朗读自适应：连续 5 次合格更新、8 s 内推进 ≥3 行进入放宽态（confirm/weak 各 -0.08、weakHits 2→1），>2.5 s 无输出或连续 3 次低置信退出；三档手动档位保留，自适应只在档位基线上微调。
- 端到端延迟补偿（默认开启，可关）：按采集分片 + 实测解码耗时 + 一帧估计延迟，按语速折算 0–0.8 行前馈到滚动目标；每 5 s 写 `voice/latency_compensation` 便于观测。
- 阅读页视觉：移除当前行底色、左侧标记条、下一行半亮、非当前行压暗、位置强调渐变与底部/顶部暗晕遮罩；正文统一一种颜色，当前行只保留下方 1.5 px 细线。
- 设置项移除「当前行高亮」「经典高亮」「下一行半亮」「按读音近似匹配」，新增「跟随延迟补偿」；旧预设读入忽略，不崩、不写回。

### Added

- 跳读硬上限不变量 `maxAutoLeapLines = 3`：闸门、跟踪器、提前跨行（含短尾捷径）三处强制 clamp，配套 5 个测试防止被改回去。

### 测试与工程

- 四检全绿：`dart analyze lib test`（apps/app、core_alignment、tool/eval）无问题、`flutter test` core 104 项 + app 212 项 + `dart test` eval 4 项通过、覆盖率 78.3%（阈值 ≥70% 未下调）、`dart format` 0 变更、`check_imports` OK。
- 10 段同口径对照（宿主机 arm64）：命中率 100%、误触发 0、最大抢行 0 行；跟随延迟 P50 877 → 837 ms、P95 1626 → 1586 ms（延迟补偿前后）。
- 30 分钟数字静音：误触发 0 次、锚点移动 0 行。阅读页改前/改后真机截图见 `docs/testing/records/20261111-follow-timing-and-visuals.md`。
- 应用图标定稿并随本版打包：深蓝渐变 `#1565C0 → #0D47A1`、白色台本横条 + 五根声波柱、第二条台本行中黄 `#FFB300`；Android 各密度 legacy/background/foreground/monochrome 四层 + `mipmap-anydpi-v26/ic_launcher.xml` 三层引用，`values-v31` 启动画面用 `splash_background`，Windows `.ico` 8 尺寸、macOS `AppIcon.appiconset`（`.icns` 由 Xcode 生成）。不重新设计图形，仅核对与打包。
- 解包 APK 核对：manifest 指向的自适应 XML 含 background/foreground/monochrome 三层，4 个 mipmap 资源 × 5 密度齐全，无旧版小牛/旧图标残留；`splash_background` 编译为 `#ff1565c0`。
- 0.27.0 release 装机（f37aa514 / Android 16）：启动器与「应用信息」均为新图标，48 px 下白条/黄条/五柱可辨；Android 12+ 冷启动深蓝底、前景居中，内容完整落在 72/108 安全区内（水平余量 ≥6/108、垂直 ≥11/108），裁切 0；通知权限弹窗标题为「大皖提词器」（该 ROM 弹窗顶部为系统通知权限示意图）。
- 构建 `0.27.0+2030` release：396,947,331 字节，SHA256 `35a5649b01edbe156b4d065eaf2ade41d85d5c0a5d6439d9cbc794ce4819c3ae`，Android Debug 证书；截图见 `docs/testing/screenshots/0.27.0/`。

## [0.26.0] - 2026-11-10

### Added

- 新增「大皖提词器」应用图标：靛蓝渐变 + 白色「台本行 → 声波」简形符号，无文字；交付 1024 母版、Android 自适应前景/背景/monochrome 各密度、Android 12+ 启动画面、Windows 多尺寸 `.ico`、macOS `.iconset`/`.icns`，生成脚本为 `tool/generate_icons.py`。
- 补齐开源仓库内容：根目录 `README.md`、`BUILDING.md`、`.gitignore`、`.github/workflows/ci.yml`、Issue/PR 模板、[第三方许可清单](../docs/legal/third-party-licenses.md)；治理文件迁移到仓库根并同步修订相对路径。

### Changed

- 应用显示名改为「大皖提词器」（英文 Dawan Teleprompter）：Android `android:label`、macOS `CFBundleName`/`CFBundleDisplayName` 与菜单、Windows 窗口标题与文件属性、应用内标题与局域网/遥控文案同步；数据库名、私有目录名与 SharedPreferences 键名保持原值，避免内部自引用不一致。
- 应用包名由 `com.tp.prompter.teleprompter` 改为 `com.dawan.teleprompter`：Android `applicationId`/`namespace` 集中到 `android/gradle.properties` 的 `appApplicationId`，MainActivity 与附属包路径同步迁移；macOS Bundle Identifier 改为 `com.dawan.teleprompter`。换包名后为全新安装，旧数据不迁移，详见 [包名变更说明](../docs/help/package-rename.md)。

### 测试与工程

- 四检全绿：`dart format` 0 变更、`apps/app` + 9 个包 `dart analyze --fatal-infos` 无问题、`check_imports` OK、`flutter test` 212 项通过、覆盖率 80.9%（阈值 ≥70%）、`license_scan` 177 包 0 冲突。
- 构建 `0.26.0+2029` 并真机验证：卸载旧包后全新安装，冷启动 1141 ms 无崩溃；启动器图标/名称、通知权限弹窗标题为「大皖提词器」；语音跟随进入「正在收音 / 跟读中（麦克风）」，静音时正确显示「未检测到语音」。详见 `docs/releases/0.26.0.md`。

## [0.25.0] - 2026-11-10

### Added

- 语音跟随改为**读音近似匹配**（默认开启）：台本与识别结果都先归一化为拼音音节序列再对齐，同音字、近音字（z/zh、n/l、前后鼻音）天然等价，不再要求文字一致。
- 多音字保留全部读音，比较时按候选集合求交（`银行` 的 `行` 同时接受 hang/xing），词内读法用 lpinyin 词语表按上下文取主读音；声调只作 0.1 的加分项，不是硬条件。
- 数字先转中文口播读法再按音节切分：`12.5%` → `百分之十二点五`，台本写数字、识别写汉字可满置信对齐；英文术语（`SDK` / `Wi-Fi` / `sherpa-onnx`）整体作为一个 token，被识别流拆开时先合并（`S D K` → `sdk`）。
- 设置页「匹配档位」下新增「按读音近似匹配」开关：默认开启，关闭即回退到逐字文字匹配；语音跟随中切换会重建台本索引并热替换对齐器，不打断麦克风。

### Changed

- 对齐代价、`span` 与置信度按**音节口径**重算：替换/漏读/多读各记 1 个音节错误，声调不同额外 +0.1；`span` = 从首个命中音节到识别末尾的音节数；`confidence = 1 - spanError / span`，语义为「命中区间内的音节一致率」（1 = 全对，0 = 全错）。DP、闸门与跟踪器框架不变，`confirm 0.55 / weak 0.35` 阈值经 10 段评测复核后保留。
- 预筛与提前跨行（early arm）改为读音候选集合求交，中文分词边界（合词或拆字）不再影响命中结果。
- 界面推进仍按字符偏移回填视觉行/字符锚点，匹配决策只来自音节命中；旧设置预设缺省按读音匹配加载。

### 测试与工程

- 新增 23 项读音回归（同音字、近音字、多音字、数字口播、英文术语、分词边界、读音/文字双口径），`core_alignment` 82 项、packages 6 包 170 项全通过。
- `apps/app` 212 项通过，覆盖率 79.4%（阈值 ≥70%）；`dart analyze` / `dart format` / `check_imports` 全绿。
- 10 段评测同口径对照（宿主机 arm64，同模型、同 20 ms 分片）：读音 100% vs 文字 97.4% 命中率，误触发均 0，跟随延迟一致；与 0.24.0 基线（x64）对照命中率 87.2% → 100%、跟随 P95 5734 → 1626 ms（ASR 解码环境不同，CER 12.0% → 11.6% 仅作参考）。
- 真机（`f37aa514`，profile 评测 harness）：10 段命中率 100%、误触发 0、`maxOverAdvance` 0、跟随 P95 1626 ms；静音 30 分钟与包信息见 `docs/testing/records/20261110-pinyin-matching.md`。

## [0.24.0] - 2026-11-10

### Fixed

- 修复段落内换行后文字不显示：视觉行测量先按 `\r\n` / `\r` / `\n` 切硬行再折行（保留空段与首尾换行），视觉行渲染固定 `maxLines: 1, softWrap: false`；真机 36/44/52 px 与横竖屏复验完整，新增 `visual_row_measurer_test` / `reader_newline_test` 回归。
- 修复语音跟随卡住时一律提示「未收音」：新增 `VoiceHealthMonitor` 与 `AsrTick` 解码心跳，按「音频分片 / 解码心跳 / 文本更新」三路计数区分 `captureStalled`、`engineStalled`、`silent`、`gateStalled` 并写入 `voice/health` 日志；采集中断时看门狗每 3 s 自动 `stop → 重开`（`voice/capture_restarted`），无需退出重进；角标文案分别显示「麦克风中断，正在重连…」「识别引擎无响应」「已收音，未匹配稿件」。
- 修复跳读过多：`LineStepGate` 的 `maxLeap` 分支先夹行再要求 `confirmConfidence`（弱置信需连续两次）；`AlignTracker` 对 `> line+5` 的候选要求 `acceptFloor`（去掉 `|| isFinal` 放行）；预筛前看 8→3 行且不再回看 `currentLine-2`，三档 `lookAheadLines` 5/8/12 → 2/3/4。真机同音频同台本由「1/21 → 19/21」变为稳定停在 `1/21`。
- 修复突然回到前面：任何 `candidate < _line` 一律 `heldBack`，删除 `_pendingBackLine/_pendingBackHits` 无确认回退；阅读页 `_advanceTo` 加单调守卫（同锚点字符也不后退），平滑模式只向前，`isFinal` 不再允许段内字符后退；锚点默认单调不后退，回退只保留手动跳行与显式重新定位。
- 去掉提词页分段：提词页始终按 `rawText` 整篇连续渲染，进度只读，移除「跳转到段落」对话框；旧标记经 `mapMarkersToContinuousLines` 按分段 `ord` 映射到连续文本语义行，旧断点经 `mapLegacyAnchorToParagraphs` 按分段顺序折算行号；遥控 `jump` 新增 `line` 并兼容旧 `sectionId`，悬浮窗/外接屏继续下发视觉行。

### 测试与工程

- 缺陷修复回归（P1–P4）：`apps/app` 210 项通过、覆盖率 79.6%（3229/4054，阈值 ≥70%），packages 6 个包 147 项通过；`dart analyze` 全绿、`dart format` 133 文件 0 变更、`check_imports` OK。包信息与真人自测清单见 `docs/releases/0.24.0.md`，真机对照与实测/推断分界见 `docs/testing/records/20261110-p1p4-device-fixes.md`。

## [Unreleased]

### Added

- 语音跟随默认模型切换为中英双语 `zipformer-bilingual-mixed`（encoder int8 + decoder/joiner fp32，约 209 MB，0.23.0）：设置新增「识别模型」可在「中英混合 / 中文轻量」之间切换，旧预设缺省按中英混合加载，不迁移或清除用户数据；14M 继续随包，可随时切回。
- 修复 D1：拉丁术语合并（`I PHONE` → `iphone`）只作用于识别流，不再合并台本索引；台本 token 偏移与 `line_step` 候选行判定保持合并前一致，10 段回归其余 9 段逐项不变。
- 修复 D2：对齐锚点只落在真正命中的 token 上，段尾未命中的替换不再把阅读锚点钉在行尾；新增「提前跨行后仍能继续推进到下一行」回归用例。
- 首次语音跟随的模型准备改为真实进度：解包阶段按 `ModelInstaller` 已写字节显示 `百分比 + 已解包/总 MB`（4 MB 分块，无定时器动画），完成后单独提示「加载识别器…（通常几秒）」；已安装的二次启动不再显示解包进度。解包失败时删除半成品并提示「已清理 / 未能清理」，SnackBar 提供「重试」入口；文案中英双语走 ARB。

### 测试与工程

- 修复本机 `flutter test` 被原生资源 hook 阻断的问题：改用 arm64 Flutter SDK（`$HOME/flutter-sdk/arm64/flutter`）执行，根因是 x86_64 SDK 经 Rosetta 调起的 `xcrun` 无法加载 arm64-only CommandLineTools 的 `libxcrun`，与是否安装完整 Xcode 无关；详见 `docs/testing/records/20261110-app-test-toolchain.md`。
- 补跑 `apps/app` 全量测试：187 项通过，覆盖率 81.1%（3157/3893 行，阈值 ≥70%）；新增识别模型默认值/切回/旧预设回落/设置页文案/语音跟随启动规格 5 项回归。
- 0.23.0 真机安装与产品口径实测：首页首启 1110 ms、冷启动 504–725 ms、热启动 190 ms；混合模型首次准备 10.7 s（含 209 MB 解包）、中文轻量 3.5 s；TOTAL PSS 空闲首页 267.2 MB、中文轻量跟读 455.7 MB、中英混合跟读 647.6 MB（相对 14M +191.9 MB）。锚点推进、首字时间与 30 分钟真实环境音仍待补测，详见 `docs/testing/records/20261110-0230-device-install.md`。
- 首读进度提示验证：`apps/app` 195 项通过、覆盖率 81.2%（3179/3915 行）；真机（0.23.0 release）首次解包约 1.5 s（38%→84% 可见）、识别器加载约 4.4 s、点按到「跟读中」约 7 s；debug 注入 `files/asr_models` 占位文件实测失败态/重试/半成品清理，重试后四个模型文件字节数与 `fileBytes` 一致。10.7 s 为端到端首次准备口径，纯解包并非 10.7 s。详见 `docs/testing/records/20261110-first-install-progress.md`。

### Added

- 文本显示改为整段连贯（0.22.0）：正文只按空行分段，段内不再按句号/逗号/120 字切成语义行，段内换行完全交给 `LayoutSnapshot` 按可用宽度自然折行；语义行 = 段落，语音对齐新增 `AlignResult.anchorCharOffset`，阅读页用 `_anchorChar` + `rowForChar` 在段内连续推进。
- 提词页功能栏支持手动隐藏/唤出：底部「隐藏功能栏」按钮把顶部/底部栏一起淡出，状态全局持久化到 `app_settings.reader_panel_hidden`；右侧常驻把手（`reader-panel-handle`）单击恢复，锁定态保留解锁角标，避免误触后找不到入口。
- 开发测试音频入口默认隐藏：demo WAV 回放只在 `kDebugMode` 或 `--dart-define=TP_DEV_AUDIO=true` 时显示（`shared/dev_flags.dart`），release 包不可见；文案改为「回放测试音频（仅开发构建）」。
- 录制时间轴 v2：`TimelineSample` 新增可选 `char`，`positionAt(ms)` 返回「段落 + 段内字符」；v1 文件在回放/导出前按 `mapLegacyAnchorToParagraphs` 迁移，SRT 用视觉行 + `captionIndex` 重映射，`timeline.json` 仍保存原文坐标。
- 遥控协议 v3：`RemoteState` 新增 `anchorOffset`、`anchorRow`、`rowProgress`、`lineUnit`、`anchorRowText`；`anchorLine` 语义明确为段落，v1/v2 上行消息继续接受，旧遥控端忽略新字段按段落粒度展示。
- 悬浮窗/外接屏改为下发视觉行：`init` 新增 `rows`/`anchorRow`/`anchorOffset`，外接屏 `lines`/`anchor` 直接使用视觉行，旧接收端回退 `lines`/`anchor`（段落粒度）。
- 断点锚点模型：`saveAnchor` 写入 `anchor_model:<scriptId>`，旧数据缺省 1；阅读页按 `initialAnchorModel` 迁移旧句行锚点到「段落 + 段内字符」，迁移结果再写回为模型 2。
- 固定阅读带阶段 C：悬浮窗下线「全稿」模式，统一为 3 行 / 5 行窗口并自动跟随锚点；旧配置 `lineCount=0` 在读取时迁移为 5 行（420 dp），设置面板移除「全稿」选项。
- 外接屏新增可选 `bandRatio`（阅读带中心占屏高比例，默认 0.5，原生夹取 0.2–0.8），按容器高度平移稿件块；旧调用不传时保持居中。
- 遥控协议 v2：状态消息新增可选 `rowHeight`、`rowCount`、`bandRatio`、`typographyModel`；主控端继续接受 v1 上行消息，配对串版本标记更新为 `v=2`。
- 固定阅读带阶段 B：篇尾完成态（默认「停止」+「循环」开关）与「已到篇尾」文案；手动/语音模式统一按末行静止 0.6 s 判定，循环模式 1.2 s 后回到篇首，且不重建语音/录制会话。
- `core_alignment` 新增 `EarlyArmDetector`：当前行已读 ≥ 55% 且下一行前 2 个 token 模糊全命中时，连续 2 次或 final 可提前跨行；严格档关闭，宽松档仅放宽阈值。
- `VoiceFollowSession.restartWith`：自动重排时热替换对齐索引/跟踪器（纯 Dart 替换，实测 < 300 ms），不重开麦克风、不重建 ASR 引擎；新增 `voice/align_restart` 耗时日志。
- 新包 `packages/core_reader_layout`（纯 Dart，MIT 同仓库）：`LayoutSnapshot` 视觉行快照与语义行/视觉行映射、`ReadingBand` 固定阅读带与镜像目标、`ReadingFollower` 一阶限速跟随、`BandEmphasis` 位置强调；文本测量由宿主注入，Flutter 侧用 `TextPainter` 实现。
- M2：局域网遥控协议与服务端（E6-1）：WebSocket JSON 帧、128-bit 配对 token 鉴权（连续 3 次失败封禁来源地址 60 s）、首条 hello 超时（5 s）、同连接命令串行与 `seq` 去重、状态按行号坐标系节流下行、二维码配对串 `tps://pair?host=...&port=...&token=...`。
- M2：遥控端页面（E6-2）：设置页新增「遥控端」入口，粘贴配对串连接主控端；展示台本标题、当前行文本、行号进度、播放/速度/镜像/锁定状态；支持上一行/播放暂停/下一行/加减速/镜像/锁定与断开；5 s 建连超时，断线 1 s 后自动重连最多 3 次，失败后可手动重连。
- M2：阅读页接入遥控（E6-3）：控制栏新增「局域网遥控」按钮，启动服务并以二维码 + 配对串展示；9 个命令映射到播放/导航/调速/跳转/镜像/锁定，锁定态忽略滚动类命令；行宽/字号变化时递增 `layoutVersion`；状态扩展 `lineCount` 与当前行文本（截断 60 字符）。
- M2：外接显示（E7-1）：阅读页控制栏新增「外接显示」按钮；通过 `tps/display` 通道枚举 HDMI/DP 副屏（多屏时弹窗选择），以 Android `Presentation` 输出黑底白字纯稿件（当前行高亮、5 行窗口、可镜像）；每 300 ms 按锚点/字号/镜像变化刷新；副屏拔出自动停止并恢复按钮状态。
- M2：扫码配对（E6-2 补充）：遥控端新增「扫码配对」，使用 `mobile_scanner` 读取主控端二维码并自动连接；相机权限拒绝/不可用/Windows 平台时展示说明并降级为原有的粘贴配对串，不阻断流程；Android 声明 `CAMERA`（camera 非必需），macOS 增加相机 TCC 与沙盒 entitlement。
- M2：录制与时间轴（E8-1）：阅读页控制栏新增录制按钮；音频以 16 kHz/单声道/16 bit PCM WAV 写入应用私有目录，10 Hz 采样当前行号形成时间轴；语音跟随已开麦时复用同一条采集流（不重复占用麦克风）；新增 `recordings` 表（数据库 schema v2 迁移），永久删除台本时级联删除音频文件。
- M2：复盘播放（E8-2）：阅读页「录制历史」面板；播放录音时按时间轴线性插值驱动稿件行号，支持播放/暂停、进度拖动、0.5×/1×/1.5×/2× 倍速与退出复盘；时间轴缺失或损坏时仍可播放但不联动稿件。
- M2：录制导出（E8-3）：导出 WAV 原文件、`timeline.json` 与按停留行生成的 `captions.srt`；使用系统「另存为」，用户取消即停止后续文件。
- M2：Android 系统级悬浮提词（W-02）：阅读页底部新增「悬浮提词」入口；首次开启弹权限说明并跳系统设置，授权返回后自动显示；未授权时提示并保留应用内提词。
- 悬浮提词窗口（W-03 基础能力）：3 行窗口、当前行高亮、原生拖拽、关闭按钮、位置记忆（dp）、独立字号；阅读页锚点变化每 200 ms 同步到悬浮窗。
- `flutter_overlay_window` 1.0.2 薄封装（MIT），仅暴露权限、显示/关闭、位置读取与参数持久化。
- 新增本地插件 `packages/overlay_bridge`（自研、仅 Android）：悬浮窗引擎与主引擎不在同一 isolate group，插件 `shareData`/`IsolateNameServer` 不可用，改由原生 `BasicMessageChannel` 双向转发 JSON，用于内容、锚点、状态与控制的跨引擎同步。
- 悬浮提词样式（W-03）：阅读设置面板新增窗口宽度（200–600 dp）、不透明度（30%–100%）、可见行数（3 行 / 5 行 / 全稿）；运行中修改即时重排窗口，参数持久化到 `overlay:global`。
- 悬浮窗双向状态同步：开始/暂停、上一行/下一行、锁定/解锁、麦克风开关均可从浮窗操作；主页面的运行态、锁定态与收音角标（加载/收音/静默/低置信/暂停）同步显示在浮窗；关闭浮窗后主页面保持同一锚点与运行态。
- Android 13+ 通知权限运行时申请；拒绝不阻断悬浮窗或语音跟随，只隐藏前台服务通知。
- 语音跟随新增 `microphone` 类型前台服务（`VoiceService`），退到其他应用或锁屏后仍满足 Android 14+ 的麦克风使用约束；停止跟随即停止服务。
- M2：`.tps` 台本包导出（台本卡片菜单）与导入（文件选择器），保留分段、备注、标记、收藏与阅读预设；导入前确认。
- M2：整包导出全部台本（含归档、排除回收站，首页工具栏）与整包导入；自动每日备份（应用私有目录 `backups/`，保留 7 份），设置页可立即备份、查看上次时间/大小/份数并导出最近备份。
- M2：`.docx` / `.pdf` 导入：Word 提取段落、段内换行与制表符；PDF 提取文本层（扫描版不支持并提示），两者进入同一导入预览页。
- M2：局域网互传（设置页）：临时 HTTP 服务 + 随机 token + 二维码；浏览器可下载全部/单篇 `.tps`，也可上传 `.tps` 直接导入。仅监听 IPv4，关闭弹窗即停止。
- M2：外观设置（设置页）：主题模式（跟随系统/浅色/深色）与强调色（靛蓝/青绿/琥珀/玫红），选择后即时生效并在下次启动恢复；只影响列表、编辑与设置页，阅读页仍按台本预设的舞台配色。
- 阅读页：语音跟随改为逐行推进（默认开启）：置信度 ≥ 0.55（final +0.15）立即切行；0.35–0.55 需连续 2 次命中；低于 0.35 不推进，连续 3 次提示低置信；单次最多前进 3 行。设置面板可关闭，回到连续平滑跟随。
- 阅读页：语音模式常驻收音角标（引擎加载中/正在收音/未检测到语音/低置信/已暂停/后台收音），使用设计令牌、不接收触摸，位于顶部阅读预留区。
- 阅读页嵌入思源黑体超粗体（Source Han Sans SC Heavy / Noto Sans SC Black，weight 900，SIL OFL 1.1），编辑页与设置页保持原有字体。
- `NOTICE` 与 `assets/licenses/`：字体来源、SHA256、OFL 许可全文随包分发。
- M1-c：全局默认阅读参数设置页（字号/行距/边距/周字数/主题/镜像/跟随参数），支持恢复默认。
- M1-c：本地 JSONL 运行日志（`app_flutter/logs/app-YYYYMMDD.jsonl`）与诊断包导出（参数头 + 日志）。
- M1-c：阅读页帧耗时采样（`reader.frame_summary`），用于高速滚动流畅度验证。
- 中英文 ARB 文案（`lib/l10n/app_zh.arb` / `app_en.arb`），应用内文案统一走 `AppLocalizations`。
- 提交前检查脚本：`tool/check_imports.dart`（分层依赖）与 `tool/check_coverage.dart`（覆盖率阈值）。
- M3：仓库治理文件：`LICENSE`（Apache-2.0，版权人 吃不饱）、`CONTRIBUTING.md`（DCO）、`CODE_OF_CONDUCT.md`、`SECURITY.md`、`TRADEMARK.md`（持有人 吃不饱）、`MODEL_LICENSE.md`（A+B：随包分发 T0 + 本地导入；权重不入 Git，清单见 `tool/models.lock.json`）。
- M3：发布与支持文档：`docs/releases/`（0.17.0 内测说明、发布检查清单）、`docs/ops/release-runbook.md`（三端构建/签名/公证/回滚）、`docs/help/`（用户手册、FAQ）、`docs/legal/`（隐私政策、用户版权限说明）。
- M3：`tool/license_scan.dart` 依赖许可扫描：扫描全部 `pubspec.lock`，按白名单识别 Apache/MIT/BSD/ISC/Zlib/Unlicense，GPL/LGPL/MPL/未知许可失败；仅允许登记不随目标平台分发的 Linux 专用依赖（当前 `dbus`）。
- 阅读页：每行字数改为自动计算（L-04，0.22.0 已随段落化下线，见 Changed）：按舞台宽度、字号、字距与台本平均字宽（全角 1.0 em / 半角 0.52 em，安全系数 1.02）估算，夹取 `[6, 80]` 字；字号/边距/字距变化与屏幕旋转、窗口缩放都会自动重排，并用「段 id + 段内偏移」保持阅读位置、递增 `layoutVersion` 让遥控端丢弃旧行号缓存。
- 阅读页：语音匹配宽松度三档（C-09，严格/标准/宽松），参数集中在 `MatchProfile` 并同时驱动逐行闸门、对齐引擎滑窗前看行数与跟踪器接受底线；设置页可切换并展示每档实际阈值（严格 0.70/0.45/+0.10/前看 5 行，标准 0.55/0.35/+0.15/前看 8 行，宽松 0.42/0.22/+0.20/前看 12 行）；档位随台本预设与全局默认持久化，未知值回落标准档；切换即时生效且保留当前锚点。

### Changed

- 段落化文本与坐标语义（0.22.0）：`splitIntoSections` 只按空行切段；`ScriptModel.fromSections` 每个分段 = 一条语义行；`LayoutSnapshot` 视觉行只由宽度决定。`anchorLine` 在新版中表示段落，遥控/悬浮窗/外接屏分别用 `anchorRow`/`rows` 表达视觉行。
- 旧台本兼容：历史分段本身是 ≤120 字块，原始空行边界已丢失，因此旧台本按「每个存储分段 = 一个段落」显示；旧断点与旧 v1 时间轴用 `mapLegacyAnchorToParagraphs` 以 40 字旧规则近似迁移（0.18–0.21 的自动每行字数无法还原，可能偏移少量行但不越界）。
- 阅读页移除自动每行字数与 `_rebuildLines`/`_maybeAutoReflow`：宽度/字号/字距变化只重建视觉行快照，语义行与语音对齐索引不变，录音/语音会话不需要重启。
- 覆盖率（0.22.0）：应用 81.7%（3093/3784 行）、`core_models` 79.9%（295/369）、`core_alignment` 91.2%（322/353）、`core_reader_layout` 93.8%（226/241）、`core_recording` 96.6%（113/117）、`core_scroll` 82.6%（57/69）、`data_store` 78.1%（429/549）；`flutter test` 182 项全部通过；未下调 70% 阈值。
- 版本号更新为 `0.22.0+2025`（三项用户反馈：段落化文本、开发音频入口、功能栏隐藏）；此前 `0.21.0+2024` 为阶段 C。
- 阅读页自动重排已随段落化删除（0.22.0）：不再有 `_maybeAutoReflow`/`_rebuildLines` 调用；阶段 B 的 `VoiceFollowSession.restartWith` 保留为未来的索引热替换入口，但当前宽度/字号变化不触发。
- 阅读页开始/恢复/跳行/停止语音/循环复位统一清理篇尾计时、循环定时器与 early arm 计数；篇尾暂停同步到遥控端与悬浮窗（`playing=false`），循环复位后恢复。
- 覆盖率（阶段 C）：应用 82.8%（3056/3689 行）、`core_alignment` 91.2%（320/351 行）、`core_reader_layout` 93.8%（226/241 行）；`flutter test` 177 项、`dart test`（40 / 24 项）全部通过；未下调 70% 阈值。
- 版本号更新为 `0.21.0+2024`（固定阅读带阶段 C：悬浮窗窗口化、外接屏带位置、遥控 v2）；此前 `0.20.0+2023` 为阶段 B、`0.19.0+2022` 为阶段 A。
- 版本号更新为 `0.20.0+2023`（固定阅读带阶段 B：篇尾 + early arm + 重排热替换）；此前 `0.19.0+2022` 为固定阅读带阶段 A。
- 覆盖率：应用 82.8%（3038/3671 行）、`core_alignment` 91.2%（320/351 行）、`core_reader_layout` 93.8%（226/241 行）；`flutter test` 174 项、`dart test`（`core_alignment` 40 项 / `core_reader_layout` 24 项）全部通过；未下调 70% 阈值，未用排除文件刷指标。
- 阅读页显示与跟随（阶段 A）：改为「固定阅读带 + 位置强调」，文字以视觉行走进阅读带，阅读带本身不随锚点移动；位置强调按行中心到带中心的距离连续衰减，不再先给新行着色再让文字追赶。
- 阅读页滚动器由二阶弹簧替换为一阶限速跟随（`core_reader_layout`）：小步指数逼近、无过冲；超过 2.5 行的目标启用追赶速度，超过 8 行的跳读直接落位并做 120 ms 淡入，不再穿越中间内容。
- 新建台本默认紧凑排版：`lineHeight` 语义改为「含行间距的总行距倍数」，默认 `1.55`；旧预设缺少 `typographyModel` 时按旧实际行距迁移（1.5 → 2.33），打开不变样；高行距旧值受新上限 2.5 约束。
- 阅读设置面板新增「经典高亮（旧观感）」开关（按行号着色，可切回旧观感）与「篇尾行为」（停止/循环）；篇尾行为字段本阶段只持久化，运行逻辑在阶段 B 接入。
- 阅读页布局快照按「文本修订 + 画布宽 + 字号/行高/字重/字距 + textScaler + 对齐」缓存，语音 partial 更新不再逐行重建 `TextPainter` 测量。
- 阅读页镜像/分光镜改为按视口中心合成矩阵，垂直镜像时滚动目标包含 `2×bandTop − H − prismDy×H` 补偿，保证锚点仍落在阅读带内。
- 版本号更新为 `0.19.0+2022`（固定阅读带阶段）；此前 `0.18.0+2021` 为自动断行 + 语音匹配档位阶段。
- 覆盖率：应用 82.7%（2931/3545 行）、`core_reader_layout` 93.8%（226/241 行），`flutter test --coverage` 171 项全部通过；新增视觉行/阅读带/跟随器/位置强调与旧预设迁移测试，未下调 70% 阈值，未用排除文件刷指标。
- 阅读设置里的「每行字数」由可调滑块降级为只读展示（显示当前窗口约可容纳字数），不再参与用户配置；旧预设中的 `maxLineChars` 读入时忽略、写回时不再输出，不报错也不丢其他字段。
- 语音跟随阈值不再硬编码：默认「标准」档与历史值完全一致（0.55 / 0.35–0.55 / final +0.15 / 弱命中 2 次 / 单次最多 3 行 / 前看 8 行），逐行闸门、对齐引擎与跟踪器统一从 `MatchProfile` 取值。
- 版本号更新为 `0.18.0+2021`（自动断行 + 语音匹配档位）；此前 `0.17.0+2020` 为 M3 发布准备阶段。
- 覆盖率 82.4%（2777/3372 行），`flutter test --coverage` 166 项全部通过；新增 `LineFit`、`MatchProfile`、档位闸门/跟踪器/引擎与旧预设迁移测试，未下调 70% 阈值，未用排除文件刷指标。
- 取消包体门禁：安装包体积只记录、不设上限、不作为合并/发布阻塞项；不做拆 ABI、裁资源等压缩取舍（优先稳定、易用、开发方便）。
- 性能基准定位调整为中高端 Android（骁龙 8 Elite / 12 GB 档）；低端机只做冒烟记录、不保证体验、不作为门禁。核查确认现无低端专属降级（未限字形缓存、未锁帧率、未简化特效、未额外降采样），无需放宽对比实测（ADR-0005）。
- 阅读页默认字重调整为 900、字距 0.8，配合内置超粗体；字号/行距/镜像/高亮逻辑未变。
- 阅读参数模型与设置面板下沉到 `lib/shared/reader_settings/`，feature 之间不再互相 import。
- feature 页面跳转改为命名路由（`app/app_routes.dart` + `app/app_router.dart`）。
- 仓库根落地 `analysis_options.yaml`（strict-casts/inference/raw-types + 项目 lint 规则），各包按规范覆盖。
- 阅读页颜色/字号/高亮尺寸改用 `design_system` 令牌。
- 阅读页默认停在起始态：打开、退出重进、切换台本后都不自动滚动/自动跟随，需轻点屏幕或点击麦克风/播放；暂停时识别结果不再移动锚点。
- 版本号更新为 `0.17.0+2020`（新增录制、时间轴与复盘）；此前 `0.16.0+2019` 为扫码配对阶段，`0.15.0+2018` 为外接显示阶段，`0.14.0+2017` 为遥控端页面与阅读页接入阶段，`0.13.0+2016` 为遥控协议与服务端阶段。
- 数据库 schemaVersion 从 1 升到 2：新增 `recordings` 表与 `idx_recordings_script` 索引，旧库通过 `onUpgrade` 原地建表。
- 遥控协议与服务端下沉到 `lib/shared/remote/`，避免 `features/reader` 跨 feature 依赖；遥控端 UI 仍留在 `features/remote/`。
- 覆盖率从 40.8%（713/1747）提升到 85.3%（1680/1970）：新增悬浮窗 UI、浮窗设置面板、权限流程、`overlay_bridge` 通道封装、日志、Provider 等组件/单元测试；未下调 70% 阈值，未用排除文件刷指标。
- 覆盖率脚本排除生成代码（`lib/l10n/generated/` 与 `*.g.dart`），与「生成代码不要求写测试」的约定对齐。
- 覆盖率 81.6%（2704/3315 行），`flutter test --coverage` 163 项全部通过；新增时间轴/SRT/WAV/导出/复盘/录制面板测试，未下调 70% 阈值，未用排除文件刷指标。

### Fixed

- 遥控二维码弹窗在 `AlertDialog` 内触发「LayoutBuilder does not support returning intrinsic dimensions」：二维码组件内部使用 `LayoutBuilder`，已给内容加固定宽度容器，避免固有尺寸查询。
- 文件导入改为「任意文件 + 代码内扩展名校验」，避免 Android SAF 按 MIME 过滤把 `.tps` 置灰不可选；非 `.txt/.md/.tps/.docx/.pdf` 明确提示。
- 局域网互传单篇下载在中文标题下挂起：`Content-Disposition` 仅使用 ASCII 文件名，无法保留时回退 `script.tps`。
- 浅色主题下正文/标题颜色退化为浅灰：`TpTheme` 改用 `TextStyle.copyWith` 保留 Material 3 排版默认色（原实现替换整个 TextStyle 丢掉了 color）。
- 阅读页左右边距失效：`OverflowBox` 沿用父级紧宽度约束把画布撑回全屏，渲染边距不生效且换行/行高与测量不一致；已放开宽度约束并统一按 `stageWidthFor()` 计算。

### Security

- Android manifest 新增 `SYSTEM_ALERT_WINDOW`（仅用户主动开启悬浮提词时跳系统设置授权）、`FOREGROUND_SERVICE` 与 `FOREGROUND_SERVICE_SPECIAL_USE`（悬浮窗前台服务），并声明 `OverlayService`（`specialUse`，exported=false）。拒绝授权时不显示悬浮窗，主流程不受影响。
- Android manifest 新增 `POST_NOTIFICATIONS`（Android 13+ 运行时申请，拒绝仅隐藏前台通知）与 `FOREGROUND_SERVICE_MICROPHONE`；新增 `VoiceService`（`microphone`，exported=false），仅在麦克风已授权且成功开始收音后启动，停止跟随即停止。
- Android manifest 新增 `INTERNET` 权限并允许明文流量，仅用于用户主动开启的局域网互传；服务带随机 token、监听任意 IPv4、关闭弹窗立即停止。

### Removed

- 阅读设置中的「每行字数（自动）」只读行、`ReaderSettingsSheet`/`SettingsPage` 的 `autoLineCharsOf` 参数，以及阅读页的自动重排链路（`_autoLineChars`/`_maybeAutoReflow`/`_rebuildLines`）。
- 阅读设置中的「每行字数」滑块（改为只读自动展示）；`ReaderSettings.maxLineChars` 字段与对应归一化/序列化逻辑。
- 日志中的台本标题、识别原文与本地文件路径（CODING §7）。
- `voice_follow` 中输出识别文本的 `debugPrint`。

## [0.3.0+2003] - 2026-11-06

### Added

- M1-b：阅读参数（字号/行距/边距/主题/镜像/高亮/跟随）与设置面板。
- 每稿预设记忆、锁定/暂停/句段跳转、常亮与沉浸式全屏。

## [0.2.0+2002] - 2026-11-05

### Added

- M1-a：台本数据模型与 drift 存储、列表/编辑器/导入、断点续读。
