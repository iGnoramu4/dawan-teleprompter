# 本地语音识别灵敏度优化方案

> 状态：draft（待评审） ｜ 责任人：ALG/FE ｜ 更新：2026-11-10 ｜ 适用：`0.22.0+2025`
>
> 范围：只做调研与方案设计。**本次未修改任何产品代码、未改版本号、未下载或安装模型权重。**
>
> 证据标注：`【查证】` 有公开来源或本地代码/记录可核对；`【估计】` 基于公开参数与工程经验的推断；`【需实测】` 必须在真机与评测集上确认。

---

## 0. 结论摘要（TL;DR）

1. **先分清两个问题**：用户说的「不灵敏」和「跟不上」不是同一件事。
   - 「跟不上」= 延迟：锚点落后于口播，通常落后 1–3 个字，属于**分块/缓冲/平滑**问题；
   - 「不灵敏」= 漏跟：某些词或句段完全不推进，属于**模型识别、音频前端、对齐/闸门**问题。
   两者要用不同指标、不同手段，不能都寄希望于「换个更大的模型」。

2. **当前链路从未在真机麦克风上闭环验证过**。项目记录里真实麦克风跟随（M1B-V1）明确标注「仅接入未验证（受模拟器限制）」；已有证据全部来自 5.15 s 回放音频（`demo_zh.wav`），并出现过 17% 低置信。**在没有真机基线数据前，无法判断「不灵敏」主要是模型问题还是参数问题。** 因此第一优先级不是换模型，而是补评测基线。

3. **当前 ASR 配置基本全是默认值**：`greedy_search`、无热词、端点检测 2.4 s / 1.2 s / 20 s、单线程；音频采集同时开启 AGC、降噪、回声消除，并使用 `VOICE_RECOGNITION + MODE_IN_COMMUNICATION`。这些都是**零模型成本**的可调项，且很可能同时影响灵敏度和稳定性。

4. **跟手性的硬下限由分块决定，不由模型大小决定**：当前 14M 模型 ONNX 元数据 `decode_chunk_len=32`，sherpa-onnx 以 10 ms 帧为 shift，即**每 320 ms 才推进一次识别结果**【查证：本地 ONNX 元数据 + sherpa-onnx `ChunkShift()` 源码】；叠加录音读取约 80 ms 与滚动平滑约 76 ms，理论下限已在 **0.5 s 左右**。换 155–199 MB 大模型不会降低这个下限，反而可能因解码更慢而更滞后。

5. **模型路线建议**：
   - 同尺寸先试 **25 MB 的 streaming zipformer-small-ctc-zh-2025-04-01**（需实测是否真的更准，不能因为「版本新」就假定更好）；
   - 若脚本有中英混说/专业术语，选 **~198 MB 的中英双语 streaming zipformer transducer**（同结构、改造最小、支持热词）；
   - 若只做中文且接受包体，**155 MB 的 large streaming CTC** 是准确率上限更高的选项，但必须确认其分块 shift 与 CER；
   - **SenseVoice / Whisper 只建议做离线或二遍校对**，不建议承担实时跟随；SenseVoice 官方权重许可是 `model-license`，不是 Apache-2.0，随包分发前必须单独评审。

6. **推荐实施顺序**：评测基线（2–3 人日）→ 设置项与音频前端 A/B（1–2 人日）→ ASR 配置与对齐/滚动修正（3–5 人日）→ 同尺寸小模型 A/B（2–3 人日）→ 再决定是否上大模型/二遍方案。**不建议直接换模型。**

### 0.1 决策记录（2026-11-10）

用户已拍板四项，本方案按此收敛；P0 评测基线已同步启动。

| # | 决策 | 对方案的影响 |
|---|---|---|
| D1 | **必须支持中英混说** | 目标模型锁定中英双语流式模型；14M 仅中文，只能作为基线/回退，不能作为终态。双语候选按「低延迟优先」评估流式能力与分块延迟。 |
| D2 | **模型随包分发（A 档），但许可不明或非宽松许可一律不进包**，改走本地导入（B 档） | 每个候选的许可结论必须逐项落到 [`MODEL_LICENSE.md`](../../MODEL_LICENSE.md) §6 与 `tool/models.lock.json`；SenseVoice 的 `model-license` 不得按 Apache-2.0 随包。 |
| D3 | **低延迟优先**：首字延迟、跟随延迟、分块延迟为一等指标，准确率次之，但**不得出现明显抢行/误触发** | 评测报告以延迟为主排序；误触发率作为红线而非优化项。 |
| D4 | **音频采集允许调整**：AGC/降噪/回声消除、音频源、缓冲区大小、重采样均列入待 A/B 项 | P1 设置项分诊后直接进 A/B，无需再等产品确认。 |

P0 基线交付物：

- 评测集与许可说明：[`eval/README.md`](../../teleprompter/eval/README.md)
- 评测工具：`tool/eval/`（宿主 CLI）与 `tool/eval_device/`（真机 harness）
- 首次基线数据：[20261110-asr-p0-baseline.md](../testing/records/20261110-asr-p0-baseline.md)
- P1 分诊 / P2 置信度修正 / P3 端点 A/B：[20261110-asr-p1p2-ab.md](../testing/records/20261110-asr-p1p2-ab.md)
  - 置信度改为「首个命中之后」统计后：命中率 87.2% → 94.9%，跟随 P95 5734 → 2220 ms，误触发仍为 0；
  - 端点 `rule1=0.8 s` 宿主最优（命中 100%、P95 1974 ms），但需真机复核句内停顿；`rule1=1.0 s` 出现误触发，淘汰。

真机实验面板（D4 落地）：

- 设置 → 实验（开发）→ 语音实验配置：`rule1`/`rule2`、AGC/NS/AEC、音频源、分片缓冲；仅调试构建可见，默认值与 0.22.0 一致；
- 配置随诊断包 header 的 `asrLab` 导出，`mic_start` / `replay_start` 事件同步记录，便于同机 A/B 对照；
- SM8750 真机已实测：面板可达、改动持久化、语音跟随可启动、诊断包字段正确。

双语 A 档前期准备（未换包、未下载权重）：

- [20261110-bilingual-zipformer-plan.md](20261110-bilingual-zipformer-plan.md)
  - int8 四件套合计 198,270,793 B（≈198.3 MB / 189.1 MiB）；RTF/PSS 为估计值，待真机；
  - `tool/models.lock.json` 已登记 `status: planned` 与已知 sha256（`tokens.txt` 待本地计算）。

---

## 1. 现状摸底

### 1.1 实际链路

```
麦克风
  └─ record 7.1.2 / record_android 2.2.0
       PCM16 / 16 kHz / 单声道 / 2×minBufferSize（约 80 ms/块，估算）
  └─ asr_kit worker isolate（asr_engine.dart）
       sherpa_onnx OnlineRecognizer（streaming zipformer transducer, int8, 单线程）
       └─ 每 320 ms 一次 chunk shift → partial text
  └─ core_alignment
       Normalizer（标点/大小写/数字读法）
       → AlignEngine（拼音模糊 + DP，窗口 200 token，带宽 40）
       → AlignTracker（acceptFloor 0.20）
  └─ reader_page
       lineStepFollow=true：
         同段内 → 直接按 anchorCharOffset 连续推进（不过闸门）
         跨段   → LineStepGate（0.55 / 0.35 / 2 次）或 EarlyArm（55% + 2 token）
  └─ core_reader_layout.ReadingFollower
       τ≈76 ms，maxSpeed 1800 px/s，catchUp 3000 px/s
```

### 1.2 当前模型与引擎

| 项 | 当前值 | 证据 |
|---|---|---|
| 模型 | `sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23` | `apps/app/assets/models/zipformer-zh-14M-int8/` |
| 参数量 | 约 14M | 【查证】sherpa-ncnn 文档 |
| 训练数据 | **仅 WenetSpeech**，仅中文 | 【查证】sherpa-ncnn 文档 |
| 词表 | 5,539 个 token，含汉字与 26 个拉丁字母；无英文 BPE 词 | 【查证】本地 `tokens.txt` 统计 |
| int8 体积 | 24.2 MiB（encoder 21.6 MB + decoder 1.89 MB + joiner 1.8 MB + tokens 48.7 KB） | 【查证】`MODEL_LICENSE.md` §2 |
| 许可 | Apache-2.0 | 【查证】Hugging Face 模型卡 |
| 解码 | `greedy_search`（未显式配置，使用默认） | 【查证】`asr_engine.dart` 未传 `decodingMethod` |
| 线程 | `numThreads = 1` | 【查证】`asr_engine.dart:59` |
| 端点检测 | 未配置，使用 sherpa 默认：rule1 2.4 s / rule2 1.2 s / rule3 20 s | 【查证】sherpa-onnx 默认 `EndpointConfig` |
| 热词 | 未启用 | 【查证】`asr_engine.dart` 未传 `hotwordsFile` |
| 分块 shift | `decode_chunk_len=32` → **320 ms** | 【查证】本地 ONNX 元数据；`ChunkShift()=decode_chunk_len_` |
| 中文 CER | **未公开**（模型卡无指标） | 【查证】未查到公开数值 |

> 结论：这是一个「14M 参数、只在 WenetSpeech 上训练、无热词、greedy、单线程」的轻量模型。它的优势是 24 MB、加载快、RTF 低；劣势是**词表小、无中英混说能力、短语/专有名词容错弱**。

### 1.3 当前音频参数

| 项 | 当前值 | 证据 |
|---|---|---|
| 编码 | PCM16 | `audio_capture.dart:33` |
| 采样率/声道 | 16 kHz / 单声道 | `audio_capture.dart:34-35` |
| 自动增益 AGC | **开** | `audio_capture.dart:36` |
| 回声消除 AEC | **开** | `audio_capture.dart:37` |
| 降噪 NS | **开** | `audio_capture.dart:38` |
| Android 音频源 | `VOICE_RECOGNITION` | `audio_capture.dart:40` |
| AudioManager 模式 | `MODE_IN_COMMUNICATION` | `audio_capture.dart:43` |
| 读取缓冲 | 插件固定 `2 × minBufferSize`；16 kHz/16 bit 下常见约 80 ms/块 | 【估计】`PCMReader.kt`；需真机确认 |
| VAD | 未接入 | 【查证】链路中无 VAD |

> 风险点：Android 的 AGC/NS/AEC 是**设备相关**的音频效果（`AudioEffectsManager` 会尝试 `AutomaticGainControl` / `AcousticEchoCanceler` / `NoiseSuppressor`）。在 `VOICE_RECOGNITION` 源上，它们可能提升近场体验，也可能**压掉辅音、抬高噪声底、造成抽吸感**，直接伤害 ASR。必须做 A/B，不能默认「全开更好」。

### 1.4 当前对齐与跟随参数

| 层 | 参数 | 当前值 | 代码位置 |
|---|---|---|---|
| 归一化 | 标点/大小写/数字读法 | 有；**英文按整词精确匹配，无音译/缩写映射** | `normalizer.dart` |
| 对齐 | 搜索窗口 | 200 token | `aligner.dart` |
| 对齐 | DP 带宽 | 40 token | `aligner.dart` |
| 对齐 | 代价 | match 0 / sub 1.0 / del 1.2 / ins 1.5 | `aligner.dart` |
| 对齐 | 置信度 | `1 - cost / (m × 1.2)`，clamp 到 [0,1] | `aligner.dart:219` |
| 对齐 | 锚点字符 | 最后一个匹配 token 的 `srcStart` | `aligner.dart:224` |
| 跟踪 | acceptFloor | 0.20 | `match_tolerance.dart:84` |
| 跟踪 | 降级/恢复 | 0.35 / 0.50 | `tracker.dart` |
| 闸门 | 强/弱/次数/跳行/final | 0.55 / 0.35 / 2 / 3 / +0.15 | `line_step_gate.dart:50-55` |
| 提前跨行 | 当前行已读比例 | 0.55 | `early_arm.dart` |
| 提前跨行 | 下一行前缀 token | 2 个 | `early_arm.dart` |
| 提前跨行 | 前缀匹配要求 | `1 - margin/2`，margin 0.10 → **每个 token ≥0.95** | `early_arm.dart:126` |
| 滚动 | τ / maxSpeed / catchUp | 76 ms（smoothness 8）/ 1800 / 3000 px/s | `reading_follower.dart:13-15,87` |
| 静音角标 | 无更新判定 | 2.5 s | `reader_page.dart:2972` |

> 注意：0.22.0 起「语义行 = 段落」，**同段内连续推进不经过闸门**（`reader_page.dart:2919-2927`）。因此：
> - 段内「跟不上」主要是 ASR 分块/准确率与锚点字符推进，不是闸门；
> - 闸门/提前跨行只在**跨段**时起作用，影响的是「换段时卡一下」；
> - 若用户关闭「逐行跟随」，则完全走连续平滑路径，跨段也不受闸门约束。

### 1.5 已知问题记录（低置信 / 仅接入未验证）

| 记录 | 状态 | 与本题的关系 |
|---|---|---|
| M1B-V1 真实麦克风输入下的语音跟随 | **仅接入未验证**（模拟器无音频源） | 说明**没有真机识别基线**，无法归因 |
| M1B-V2 锁定态跟随（回放 `demo_zh.wav` 5.15 s） | 实测通过 | 证据来自短回放，置信度出现 0.17 / 0.63 |
| R3-01 逐行跟随（回放） | 实测通过 | 58% 单次命中即切行；短音频不覆盖连续口语 |
| R3-04 平滑模式连续平移观感 | **仅接入未验证** | 关闭「逐行跟随」的观感没有对照数据 |
| R4-04 低置信角标 | 实测通过 | 确认真实出现 17% 低置信 |
| R4-05 / R4-06 加载态、后台态角标 | **仅接入未验证** | 与识别链路状态有关，需真机补测 |
| 20261109 匹配档位记录：三档在真实噪声环境的手感 | **仅接入未验证** | 档位阈值只有单测与回放，没有噪声环境对照 |
| 20261106-m2-recording：真实麦克风采集、权限弹窗、跟随+录制并发 | **仅接入未验证** | 并发采集可能影响音频质量与时序 |
| 20261109-reading-band-stage-b：真机麦克风下自动重排录音连续 | **未验证** | 重排会热替换对齐索引，需真机确认不丢字 |
| M3 发布准备：真机安装、相机/麦克风授权、30 分钟长录 | **未验证** | 长稳与热稳定性没有数据 |
| `models.lock.json`：模型上游许可 | `pending-upstream-verification` | 本次查证 HF 卡为 Apache-2.0，可回填但需负责人确认 |
| `docs/testing/TESTING.md` §5 评测集（60 段） | **方法论已写，`eval/` 目录不存在** | 评测基线尚未落地，是本方案 P0 |

> **这些记录共同说明**：当前「不灵敏」的反馈是**第一次真机真实输入反馈**，而此前所有通过项要么是回放、要么是单测。把「不灵敏」直接归因于 14M 模型，证据不足。

---

## 2. 归因假设与 10 分钟分诊

### 2.1 五个可区分 hypothesis

| 假设 | 典型现象 | 快速判断 | 对应动作 |
|---|---|---|---|
| H1 分块/缓冲延迟 | 稳定落后 1–3 个字，但一直在动 | 关闭平滑/提高 smoothness 后改善不明显；日志 `decodeMs` 远小于 320 ms | 换更小 chunk 的模型 / 降缓冲；加锚点前瞻 |
| H2 ASR 漏词/错词 | 某些词后停住，之后又突然跳一段 | 含英文、数字、专有名词处最容易停 | 换模型 / 热词 / 英文归一化 |
| H3 音频前端 | 近场还行，远场/噪声/外放时明显变差 | 关 AGC/NS/AEC 或换音频源后改善 | 音频 A/B |
| H4 对齐/置信度 | 置信度长期 <0.35，`confidence` 低但文本大致对 | 打开诊断日志看 `confidence` 与 `cost` | 改置信度公式/去口头语/调带宽 |
| H5 闸门/提前跨行 | 段内正常，**换段时**卡 0.3–1 s | 关闭「逐行跟随」或切「宽松」后改善 | 调闸门/提前跨行 |

### 2.2 用户可在 10 分钟内完成的分诊

1. **切换「语音匹配档位」到「宽松」**，同一段读 2 分钟。若明显改善 → H5 或 H4。
2. **关闭「逐行跟随」**（设置 → 阅读 → 逐行跟随），同一段读 2 分钟。仅作诊断，可能抢行。若明显改善 → H5。
3. **改变距离**：20 cm 近场 vs 1 m 远场；安静房间 vs 有空调/音箱。若差异巨大 → H3。
4. **读一段含英文/数字/品牌的稿子**（如「我们用 AI 做 PPT，2026 年 Q3 上线」）。若只在英文/数字处停 → H2。
5. **观察落后幅度**：是 1–3 个字（H1）还是「一整段不动」（H2/H4/H5）。

> 这五步不需要改代码，也不需要模型，建议先让用户做一轮，把结果作为方案选型的输入。

---

## 3. 路线一：模型替换

### 3.1 候选对比

> 说明：体积均为 **int8 / 量化后**；「流式分块」是影响跟手性的关键列，缺失的必须实测确认，不能只看参数量。

| 候选 | 参数量 / 体积 | 流式与分块 | 中文覆盖 / 公开指标 | 热词/上下文偏置 | 许可 | 适配成本 | 结论 |
|---|---|---|---|---|---|---|---|
| **现状** zipformer-zh-14M-2023-02-23 | 14M / 24.2 MiB | 流式 transducer；shift **320 ms** | 仅 WenetSpeech、仅中文；**无公开 CER** | 支持（需 `modified_beam_search`） | **Apache-2.0**【查证】 | — | 基线；中英混说能力弱 |
| **zipformer-small-ctc-zh-2025-04-01** | 小型 / **25 MB** | 流式 CTC；分块未公开【需实测】 | 中文；**无公开 CER** | CTC 不支持热词 | 模型卡无 license 元数据；训练代码 icefall Apache-2.0【需确认】 | 中（transducer→CTC，需改 `AsrModelSpec`） | **同尺寸首选 A/B**，但不能假定一定更好 |
| **zipformer-ctc-zh-2025-06-30** | ~160M / **155 MB** | 流式 CTC；分块未公开【需实测】 | 中文多数据集；同源 icefall large 流式 CTC 公开 CER：AISHELL-1 test **1.97%**、WenetSpeech meeting **8.13%**、net **10.62%**【查证，参照值】 | CTC 不支持热词 | 发布页未标注；icefall 代码 Apache-2.0【需确认】 | 中高（模型规格、内存、按需分发） | 中文准确率上限更高；先确认分块与 RTF |
| **zipformer-bilingual-zh-en-2023-02-20** | 80M / **~198 MB**（encoder 182 + decoder 13.1 + joiner 3.2） | 流式 transducer；默认 chunk 32（320 ms），另有 64/96 变体 | 中英双语；训练自数万小时内部商用数据【查证】；**无公开 CER** | **支持**（`modified_beam_search`） | **Apache-2.0**【查证】 | 低（同结构，换 assets + spec） | **中英混说首选**；包体代价大 |
| **streaming-paraformer-bilingual-zh-en** | — / **~226 MB**（encoder 158 + decoder 68） | 流式 Paraformer；分块未公开，通常更大【需实测】 | 中英 + 多方言；无时间戳【查证】 | 不支持热词 | 镜像标 Apache-2.0；上游 ModelScope 需核对【需确认】 | 中高（新模型族） | 方言场景候选；延迟风险高 |
| **SenseVoiceSmall** | 234M / **228 MB** int8 | **非流式**，需 VAD 分段；段级延迟 | 中/粤/英/日/韩；官方声称中文/粤语优于 Whisper（具体 CER 在图片中，未取数值）【查证-定性】 | 无 | 官方卡 **`model-license`**（指向 FunASR 模型协议，允许商用但非标准白名单）【查证】 | 高（二遍/分段） | 只建议离线或二遍校对 |
| **Whisper small / large-v3-turbo** | 244M / 809M；量化后约 150 MB / 500–800 MB【估计】 | **非流式**，30 s 窗口 | 中文强，但非流式；不适合逐字跟随 | 无 | **MIT**【查证】 | 高 | 只做离线对齐/校对 |
| **Vosk small Chinese** | — / ~42 MB【估计】 | 流式 Kaldi | 中文；准确率低于 Zipformer 系【估计】 | 语法/有限 | Apache-2.0【查证】 | 中 | 仅作对照组，不推荐主线 |

### 3.2 关键取舍

- **跟手性**：模型替换**不会**降低 320 ms 的分块下限；只有「新模型导出时 chunk shift 更小（如 16 → 160 ms）」才会直接改善。选型时必须先读模型元数据/导出脚本确认 `decode_chunk_len`，而不是只看 CER。
- **准确率**：14M → 160M 的收益是实打实的（参数量 10 倍），但代价是 6.5 倍体积与更高 RTF；对「读稿」场景，14M 的错字可能仍够对齐用，真正卡住的是**英文/数字/专名**，这类问题用热词或双语模型更直接。
- **中英混说**：当前 14M 词表只有 26 个拉丁字母、无英文 BPE，英文词会被拆成字母或直接丢；`Normalizer` 又按整词精确匹配英文。**只要脚本里有 AI/PPT/APP/品牌名，当前模型几乎必然在那些位置停住**。这不是「调灵敏度」能解决的，必须换双语模型或在归一化层做英文缩写映射。
- **许可**：当前 14M 的 Apache-2.0 已查证；SenseVoice 官方卡是 `model-license`，**不能按 Apache-2.0 处理**；Paraformer 镜像的 Apache-2.0 不能替代上游 ModelScope 的许可；CTC 2025 系列模型卡未标注 license，发布前必须补核对。
- **分发方式**：`MODEL_LICENSE.md` 已定 A+B；155–199 MB 模型建议走 **B 本地导入 / 按需下载**，不要直接塞进 APK。当前 B 档入口尚未实现。

### 3.3 推荐

1. **先做同尺寸 A/B**：25 MB small CTC。若 CER 与跟随命中率不优于 14M，直接放弃，不进入大模型。
2. **若中英混说是硬需求**：直接评估 198 MB 双语 transducer；它是同结构，改造最小，且支持热词。
3. **若只做中文、且接受包体**：155 MB large CTC 作为「高精度模式」候选，但必须实测分块 shift、RTF、内存与 30 分钟热稳定。
4. **SenseVoice/Whisper 不进实时链路**；最多作为「录制结束后离线校对/生成更准字幕」的二遍能力。

---

## 4. 路线二：参数调优

> 原则：每条只改一个变量；用评测集对比；不要同时改端点、beam、增益和闸门，否则无法归因。

### 4.1 ASR 侧

| 参数 | 当前值 | 建议值 | 预期收益 | 风险 | 验证 |
|---|---|---|---|---|---|
| 端点 rule1 / rule2 / rule3 | 默认 2.4 / 1.2 / 20 s | **1.6 / 2.0 / 30 s**（先试） | 减少句中 1.2 s 静音就 reset 导致的上下文丢失；减少「停顿后重新起跑」 | final 更晚；长句不 final；极端长稿可能累积 | 统计每分钟 endpoint 次数、停顿后首字延迟、跨段命中率 |
| 端点策略 B | 默认 | **关闭 endpoint，30 s 强制 reset** | 连续上下文最好，减少 reset 抖动 | 文本无限增长，DP 成本上升；错误累积 | 30 min 长跑、DP 耗时、CER 漂移 |
| 解码方法 | `greedy_search` | **`modified_beam_search` + maxActivePaths 4** | 降低替换/删除错误，尤其专名 | CPU 约 1.5–2×，decodeMs 上升 | RTF p95、CER、首字延迟 |
| 热词 | 无 | 从台本抽取 50–100 个专名/英文/数字，`hotwordsScore=1.5` | 专名、品牌、缩写命中率提升 | 过度偏置导致误匹配；热词文件启动时加载，不能按行热更 | 专名 CER、误触发率 |
| 线程数 | 1 | **2**（再试 4） | 降低 decodeMs | 功耗/发热；长跑降频 | decodeMs p95、电池温度、1 h 耗电 |
| blankPenalty（仅 CTC） | 0 | ±0.5 网格 | 调删除/插入权衡：正值减少删除，利于连续跟随 | 插入增多，误触发 | CER、漏跟事件、误触发 |
| 分块 shift | 320 ms | 选 **≤160 ms** 的导出（若有） | 直接降低首字/跟随延迟 | 小 chunk RTF 更高；模型可能不存在小 chunk 版本 | 首字延迟 p95、RTF |

> **重要**：`modified_beam_search` 是热词生效的前提（sherpa-onnx 的热词只支持 transducer 的 modified_beam_search）。当前代码没有传 `decodingMethod`，所以热词即使加了也不会生效；这是「改配置即可」的典型项。

### 4.2 对齐/跟踪侧（不改模型也能提高「灵敏度」）

| 参数 | 当前值 | 建议值 | 预期收益 | 风险 | 验证 |
|---|---|---|---|---|---|
| 置信度分母 | `m × 1.2` | **`m × 1.5`（= insCost）** | 口头语/插入多时置信度不再被过度惩罚；减少「文本对了但置信度低」的卡顿 | 置信度整体抬高，闸门更容易过 | 置信度分布、漏跟/误触发 |
| 口头语处理 | 无 | 归一化时去掉「嗯/啊/呃/那个/就是/然后」等填充词 | 直接减少插入代价 | 误删真实词（「然后」作为正文） | CER、置信度、误删抽检 |
| DP 带宽 | 40 | **60–80** | 跳读/重复后更快重新对齐 | 误匹配/抢行；DP 耗时略增 | 跳读收敛句数、误触发 |
| 锚点字符 | 最后匹配 token 的 `srcStart` | 加 **+1 字前瞻**（或 +0.2 行） | 抵消 320 ms 分块带来的「永远差一个字」 | 停顿/结尾时略超前 | 稳态误差、用户主观 |
| 段内最低置信 | 无（段内不过闸门） | 保持；但 `anchorCharOffset` 可加 **1 字偏置** | 同上 | 同上 | 同上 |
| 闸门（跨段） | 0.55 / 0.35 / 2 次 | 标准档试 **0.50 / 0.30 / 2 次**；或直接用内置「宽松」0.42 / 0.22 / 1 次 | 跨段更跟手 | 抢行/越段 | 跨段命中率、越段次数 |
| EarlyArm 前缀 | 每个 token ≥0.95 | margin 0.10 → **0.20**（≥0.90），或 tokens 2→1 | 提前跨行更容易触发 | 下一行误判导致抢行 | 跨段延迟、抢行次数 |
| 滚动平滑 | τ 76 ms / 1800 px/s | **τ 50 ms / 2400 px/s** | 减少「追上目标」的视觉延迟 | 抖动/眩晕 | 帧耗时、用户主观 |

> 置信度公式的现状值得单独说明：`1 - cost/(m×1.2)`，而单次插入代价是 1.5。也就是说，**m 较小时，一个「嗯」就能把置信度打到 0.17 左右**（与记录中的 17% 吻合）。这不是模型识别错误，而是**对齐置信度的归一化偏严**。如果真机日志里低置信大多伴随插入（口头语），优先改这里，而不是换模型。

### 4.3 不建议现在做的

- 不要为了「更灵敏」直接把 `acceptFloor`、`confirmConfidence` 全部降到 0；会显著增加抢行，且掩盖真正的 ASR 漏词。
- 不要同时开 `modified_beam_search` + 大模型 + 4 线程 + 关闭音频效果；一次只动一个变量。
- 不要在没有基线的情况下调 `maxLeap`；越段是用户最反感的错误之一。

---

## 5. 路线三：音频前处理

### 5.1 处理链选项

| 项 | 当前 | 建议 | 预期收益 | 风险 | 验证 |
|---|---|---|---|---|---|
| AGC 自动增益 | 开 | **先关**，用固定软件增益/峰值归一化到 -3 dBFS | 避免抽吸、噪声底抬升、削波 | 远场/小声时变轻 | 近场/远场 CER、削波率 |
| 降噪 NS | 开 | **先关**（或仅保留设备默认） | 避免辅音被削、ASR 特征失真 | 噪声环境更差 | 3 种噪声场景 CER |
| 回声消除 AEC | 开 | **阅读时无外放则关**；有 TTS/外放则保留 | 避免近端语音被 AEC 误伤 | 外放时回声 | 外放/耳机 A/B |
| VAD | 无 | 先只用于**评测与录制分段**；是否门控解码需 A/B | 可减少静音解码与噪声误触发 | 门控会切掉字头，增加首字延迟 | 首字延迟、静音误触发 |
| 音频源 | `VOICE_RECOGNITION` | 依次试 `voicePerformance`（Android 10+）→ `unprocessed` → `mic` | 找到该机型最适合 ASR 的源 | 设备差异极大；`unprocessed` 可能很小声 | 6 组矩阵 A/B |
| AudioManager 模式 | `MODE_IN_COMMUNICATION` | 试 `MODE_NORMAL` | 避免通话模式带来的额外处理/路由 | 部分机型外放/音量行为变化 | 音量、路由、CER |
| 采样率/位深 | 16 kHz / 16 bit | **保持不变** | 模型要求；改动无收益 | 重采样引入伪影 | — |
| 读取缓冲 | 2×min（约 80 ms） | 目标 **40 ms**（需改插件/原生采集） | 直接降 ~40 ms 首字延迟 | 欠载/爆音；设备差异 | 丢帧率、首字延迟 |
| 双麦/阵列 | 未使用 | **不建议投入** | 理论上有波束成形收益 | Android 应用层无可靠阵列 API；机型差异大 | 仅记录，不做门禁 |

### 5.2 推荐的 A/B 顺序

1. **音频源 × 效果开关**（6 组）：`voiceRecognition/mic/unprocessed` × `effects on/off`，每组 3 段 × 1 分钟，先看 CER 与首字延迟。
2. **AGC 单独开关**：固定其他项，确认 AGC 是否伤害近场。
3. **软件增益**：在关闭 AGC 后，比较 0 / +6 / +12 dB 与峰值归一化。
4. **缓冲**：只有在 1–3 都稳定后再改，避免把欠载误判为识别问题。

> 结论：音频前处理是**最低成本、最容易被忽略**的一层。尤其 `AGC + NS + AEC 全开 + VOICE_RECOGNITION + MODE_IN_COMMUNICATION` 是一个「为通话优化」的组合，不一定适合「连续读稿的 ASR」。

---

## 6. 评测方法：怎样客观判断「更灵敏」

### 6.1 沿用项目既有口径

`docs/testing/TESTING.md` §5 已经定义了 60 段评测集与核心指标：

- 普通话男声 12、女声 12、方言口音 10、中英混读 8、口误/重复/甩词 8、跳读/插话 6、噪声/回声 4；
- 每段 60–120 s，人工标注「每句话对应的脚本 token 区间」；
- 目标：首字跟随延迟 ≤500 ms（P95 ≤800 ms）、稳态误差 ≤0.5 行（P95 ≤1 行）、跳读收敛 ≤2 句、静音误滚动 <1 次/30 min、口误回跳 0 次/30 min、60 min 连续稳定。

**但 `eval/` 目录当前不存在，§5 尚未落地**【查证】。本方案把「建评测集与跑基线」列为 P0，而不是继续用 5.15 s 回放和主观感受。

### 6.2 需要补充的指标定义

| 指标 | 可执行定义 | 采集方式 |
|---|---|---|
| **CER** | 归一化（去标点、统一数字读法、英文小写）后 `(S+D+I)/N`；分别统计「全体 / 专名 / 中英混读 / 数字」 | 最终识别文本 vs 人工转写 |
| **首字延迟** | 音频能量/VAD 判定说话起点 → 首次 `anchorChar` 变化；按段统计 p50/p95 | 诊断日志时间戳 + 音频时间戳 |
| **跟随命中率** | 每 250 ms 采样：`|anchorChar - 标注Char| ≤ 5 字` 记为命中；同时报「±1 段」 | 标注文件 + 日志回放 |
| **漏跟事件** | 有语音且锚点落后标注 >10 字，持续 >500 ms，记 1 次 | 同上 |
| **误触发/抢行** | 无语音时锚点移动，或锚点超前标注 >10 字；按 30 min 统计 | 静音片段 + 日志 |
| **回跳率** | 锚点向后跳的次数/分钟 | 日志 `anchorChar` 序列 |
| **RTF** | `decodeMs / 音频块时长`，p50/p95 | `asr_engine.dart` 的 `decodeMs` |
| **内存** | 跟随 10 min 后 RSS 增量与峰值 | `adb shell dumpsys meminfo` |
| **长稳** | 60 min 无崩溃、无累计漂移、无热降频导致的 RTF 恶化 | 长跑 + `thermalservice` |

> 「更灵敏」的验收不是「感觉更好」，而是：**漏跟事件相对基线下降 ≥30%，同时误触发 ≤1 次/min、CER 不退化 >5%**。任何一项不达标都不算优化成功。

### 6.3 评测集设计（可执行）

在既有 60 段基础上，建议补齐以下「口语/混说」压力段：

| 类型 | 数量 | 设计要点 |
|---|---|---|
| 正式口播 | 10 | 新闻/发布会，语速 4–5 字/s，标点清晰 |
| 即兴口语 | 10 | 含「嗯/那个/就是/然后」、重复、改口 |
| 数字/单位 | 8 | 年份、百分比、金额、型号（如「2026 年 Q3」「百分之 3.5」） |
| 中英混说 | 8 | AI/PPT/APP/品牌名/缩写 |
| 专名/术语 | 8 | 人名、地名、产品名、缩写 |
| 跳读/插话 | 8 | 中途跳段、重复上一段、被提问打断 |
| 噪声/回声 | 8 | 空调、人群、外放回声；近场/远场各半 |

每段 60–120 s；标注格式沿用 `eval/labels/*.json`（句子 → token 区间）。**至少保留 20% 作为留出集**，不能在同一批数据上反复调参。

### 6.4 真机步骤（骁龙 8 Elite / 12 GB）

1. 安装 **profile/release** 构建（不要用 debug 判断性能），确认 `RECORD_AUDIO` 已授权。
2. 飞行模式、关闭其他音频应用、媒体音量 0、屏幕亮度固定、关闭省电模式、电量 >50%。
3. 手机置于 20 cm / 50 cm / 1 m 三个距离；每个距离读 3 段（正式、口语、中英混说），每段 3 次，顺序随机。
4. 采集：应用诊断包（`follow_update` / `decodeMs` / `confidence` / `line`）、`adb shell dumpsys meminfo`、`adb shell dumpsys thermalservice`、`adb shell top -H`。
5. 连续跑 30 min（发布门禁至少 60 min），记录掉帧、温度、RTF 漂移、内存增长。
6. 输出 `build/eval-report.json`：每个配置的 CER、首字 p50/p95、命中率、漏跟/误触发、RTF、内存；与 `eval/baseline.json` 对比。
7. 先用**回放 WAV**（现有 `startReplay` 能力）做确定性对照，排除人声差异；再用真人麦克风复核前 2 名配置。

> 注意：当前 UI 里的「首字」是 `utteranceElapsedMs`（从 utterance 开始计时，包含起点静音），**不是**从说话起点算起的首字延迟。评测必须用音频能量/VAD 起点重新计算，不能直接拿 UI 数字当指标。

---

## 7. 排期与成本

> 估算假设：1 名工程师全职、含自测、不含跨团队评审与法务时间；人日为量级估计。

| 优先级 | 工作 | 人日 | 预期收益 | 依赖 |
|---|---|---|---|---|
| **P0** | 建 `eval/` 评测集、标注、回放/日志工具、跑 14M 基线 | 2–3 | 把「感觉」变成可比较的数字；避免盲调 | 无 |
| **P1** | 设置项分诊：宽松档、关闭逐行跟随、音频源/效果 A/B | 1–2 | 可能立即缓解；确定问题层级 | P0（至少先手工记录） |
| **P2** | ASR 配置：端点、beam、热词、线程、CTC blankPenalty | 2–3 | 专名/数字更准；减少 reset 抖动 | P0 |
| **P3** | 对齐/滚动：置信度分母、去口头语、DP 带宽、锚点前瞻、EarlyArm、τ | 2–3 | 直接改善「差一个字」和跨段卡顿 | P0 |
| **P4** | 同尺寸 small CTC 25 MB A/B | 2–3 + 1 评测 | 可能在不增包体的情况下提升准确率 | P0/P2 |
| **P5** | 大模型：155 MB CTC 或 198 MB 双语 transducer | 3–5 + 1 评测 | 中文准确率/中英混说提升 | P4 结论、许可确认、分发方案 |
| **P6** | 二遍：SenseVoice/Whisper 离线校对 | 5–10 | 录制后字幕更准，不影响实时 | 许可评审、产品定义 |
| **P7** | 原生音频：40 ms 缓冲、音频源/增益精细化 | 3–8 | 降低 40–80 ms 延迟 | 设备实测、插件改造 |

### 推荐实施顺序

```
P0 评测基线
  ├─ P1 设置项分诊（当天可做，先给用户缓解）
  ├─ P2 ASR 配置（与 P3 可并行，但一次只改一组）
  └─ P3 对齐/滚动
        └─ P4 同尺寸小模型
              ├─ 若 CER/命中率不达标 → 停止，回到 P2/P3
              └─ 若达标 → P5 大模型/双语（按用户拍板）
                    └─ P6 二遍（仅离线价值明确时）
P7 只在 P0 证明延迟瓶颈在缓冲时启动
```

**推荐第一轮总投入：5–8 人日**（P0 + P1 + P2/P3 的一部分），先拿到数据再决定是否进入 P4/P5。

---

## 8. 风险与取舍

### 8.1 换模型的代价

| 风险 | 说明 | 缓解 |
|---|---|---|
| **包体** | v0.17.0 APK 已约 200 MiB；14M 模型仅 24 MiB。换 155/199 MB 模型会使 APK 增加约 130–175 MB | 走 B 本地导入/按需下载；不要把大模型塞进 A 档 |
| **许可** | SenseVoice 官方 `model-license`；Paraformer 上游 ModelScope 待核对；CTC 2025 卡未标 license | 发布前逐项回填 `MODEL_LICENSE.md` §3.3；未确认不随包 |
| **内存** | 大模型 + ORT arena 可能增加 200–400 MB RSS；现有基线 <400 MB | 真机 12 GB 可承受，但要测后台被杀与 30 min 增长 |
| **功耗/发热** | 大模型 + beam + 多线程 → 持续读写时降频 | 限制线程、按需启用「高精度模式」、监控温度 |
| **首字延迟** | 大模型 decode 更慢；若分块 shift 更大，延迟更差 | 选 chunk ≤320 ms 的导出；不要用大模型解决延迟 |
| **稳定性** | 大模型在噪声/口音下不一定更稳，可能更「自信地错」 | 用误触发/抢行指标约束，不只 CER |

### 8.2 「更灵敏」与「更稳」的取舍

| 调法 | 更灵敏 | 更稳 | 建议 |
|---|---|---|---|
| 降低闸门/acceptFloor | ✅ | ❌ 抢行 | 只对段内/低风险场景放宽；跨段保留闸门 |
| 提高热词权重 | ✅ 专名 | ❌ 误匹配 | 限制词表 50–100，专名为主 |
| 关闭音频效果 | ✅ 近场 | ❌ 噪声 | 按场景切换（安静/嘈杂） |
| 加大 beam | ✅ 准确 | ❌ CPU/延迟 | 2–4 路，实测 RTF |
| 锚点前瞻 | ✅ 观感 | ❌ 停顿略超前 | +1 字起步，A/B |
| 换大模型 | ✅ 准确 | ⚠️ 延迟/功耗 | 仅在高精度模式 |

**产品建议**：保留「标准/宽松」两档即可，不必新增第四档；把「宽松」明确标注为「更跟手，可能抢行」，把「标准」标注为「更稳，换段可能慢半拍」。这样用户能自己选取舍，而不是让默认值同时满足两个矛盾目标。

---

## 9. 需要拍板的选择项

| # | 选择 | 选项 | 结论 / 建议 |
|---|---|---|---|
| 1 | 包体/分发 | A 随包 / B 本地导入 / 按需下载 | **已定**：A 档随包，但以许可为门禁——许可不明或非宽松许可一律改 B 档（见 D2） |
| 2 | 是否必须中英混说 | 必须 / 不必须 | **已定**：必须。目标模型锁定中英双语流式模型 |
| 3 | 优先级 | 低延迟 / 高准确 / 高稳定 | **已定**：低延迟优先，但误触发/抢行为红线 |
| 4 | 是否允许改音频采集 | 关闭 AGC/NS/AEC、换音频源、缓冲区 | **已定**：允许，列入 A/B |
| 5 | 是否接受二遍式 | 流式跟随 + 离线校对 | **待定**：可作为独立功能，不参与实时滚动 |
| 6 | 是否先做评测基线 | 先评测 / 直接换模型 | **已定**：先评测；P0 已落地，见 `eval/README.md` |
| 7 | 是否启动 SenseVoice 许可评审 | 是 / 否 | **待定**：只有确定要做离线二遍时才启动 |

---

## 10. 附录

### 10.1 查证来源

> 访问日期：2026-11-10。公开页面可能随上游更新，发布前需复核。

- [sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23（HF 模型卡，Apache-2.0）](https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23)
- [sherpa-ncnn Zipformer 文档：14M 模型训练自 WenetSpeech、仅中文](https://csukuangfj.github.io/sherpa/ncnn/pretrained_models/zipformer-transucer-models.html)
- [sherpa-onnx 在线 Zipformer transducer 模型列表](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/online-transducer/zipformer-transducer-models.html)
- [sherpa-onnx 在线 CTC 模型列表（small 25 MB / large 155 MB）](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/online-ctc/zipformer-ctc-models.html)
- [sherpa-onnx streaming Paraformer 模型（int8 158+68 MB）](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/online-paraformer/paraformer-models.html)
- [icefall multi_zh-hans RESULTS（large streaming CTC CER）](https://github.com/k2-fsa/icefall/blob/master/egs/multi_zh-hans/ASR/RESULTS.md)
- [中英双语 streaming zipformer（HF 模型卡，Apache-2.0；80M/620 MB 仓库）](https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20)
- [k2-fsa 模型介绍：双语模型 80M、数万小时内部商用数据](https://k2-fsa.org/zh-CN/models/asr/)
- [sherpa-onnx 热词文档：仅 transducer 的 modified_beam_search 支持](https://k2-fsa.github.io/sherpa/onnx/hotwords/index.html)
- [SenseVoiceSmall 官方模型卡（License: model-license）](https://huggingface.co/FunAudioLLM/SenseVoiceSmall)
- [SenseVoice 官方仓库（中文/粤语优于 Whisper 的定性声明；15× 速度声明）](https://github.com/FunAudioLLM/SenseVoice)
- [sherpa-onnx SenseVoice 预训练模型（int8 228 MB）](https://k2-fsa.github.io/sherpa/onnx/sense-voice/pretrained.html)
- [Whisper large-v3-turbo（HF 模型卡，MIT）](https://huggingface.co/openai/whisper-large-v3-turbo)
- [sherpa-onnx 源码：`ChunkShift() = decode_chunk_len_`](https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/master/sherpa-onnx/csrc/online-zipformer-transducer-model.h)

### 10.2 本地代码与记录索引

- ASR 配置：`packages/asr_kit/lib/src/asr_engine.dart:59,180-215`
- 音频采集：`packages/asr_kit/lib/src/audio_capture.dart:33-43`
- 模型清单：`teleprompter/tool/models.lock.json`、`teleprompter/MODEL_LICENSE.md`
- 对齐置信度：`packages/core_alignment/lib/src/aligner.dart:219-228`
- 匹配档位：`packages/core_alignment/lib/src/match_tolerance.dart:63-99`
- 闸门/提前跨行：`packages/core_alignment/lib/src/line_step_gate.dart:50-55`、`early_arm.dart:126`
- 阅读页同段/跨段分支：`apps/app/lib/features/reader/reader_page.dart:2919-2955`
- 滚动跟随：`packages/core_reader_layout/lib/src/reading_follower.dart:13-15,87`
- 既有测试记录：`docs/testing/records/20261106-m1c.md`、`20261106-m2.md`、`20261109-reader-auto-wrap-match-tolerance.md`
- 评测方法：`docs/testing/TESTING.md` §5

### 10.3 术语

- **chunk shift**：流式模型每次向前推进的音频帧数；本项目 32 帧 × 10 ms = 320 ms。它决定 partial 结果的最小更新间隔，是跟手性的硬下限。
- **CER**：字符错误率，`(替换 + 删除 + 插入) / 参考字符数`。
- **RTF**：实时率，`解码耗时 / 音频时长`；<1 才实时。
- **A 档 / B 档**：`MODEL_LICENSE.md` 定义的「随包分发 / 用户本地导入」两种模型分发方式。
