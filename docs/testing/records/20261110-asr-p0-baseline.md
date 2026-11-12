# ASR 跟随 P0 基线记录（2026-11-10）

> 关联：[本地语音识别灵敏度优化方案](../../design/20261110-asr-sensitivity-optimization.md) §0.1 ｜ 评测集：[eval/README.md](../../../teleprompter/eval/README.md)
>
> 结论先行：**「不灵敏」的当前证据同时指向模型能力与对齐/闸门参数，但后者成本低得多；「跟不上」主要是 320 ms 分块 + 端点累积文本导致的语义滞后，与模型大小无关。**

## 1. 环境

| 项 | 值 |
|---|---|
| 运行方式 | 宿主 CLI 回放（非真机麦克风） |
| 机器 | Apple M4 Max / 36 GB / macOS |
| Dart | 3.13.7 stable，`macos_x64`（Rosetta，RTF 仅作数量级参考） |
| 模型 | `zipformer-zh-14M-int8`（Apache-2.0，仅中文） |
| ASR 配置 | `greedy_search`、1 线程、端点 2.4 / 1.2 / 20 s、无热词 |
| 音频 | 16 kHz / 单声道 / PCM16，20 ms 分片 |
| 评测集 | P0 合成语音 10 段（`say` Tingting），合计约 3.5 min |
| 对齐/闸门 | `MatchProfile.standard`，复刻 `reader_page.dart` 0.22.0（`lineStepFollow=true`） |

## 2. 总体结果

| 指标 | 数值 |
|---|---|
| CER（token 级） | **12.0%**（82 / 684） |
| 跟随命中率 | **87.2%**（34 / 39 行） |
| 首字延迟 P50 / P95 | **460 / 780 ms** |
| 跟随延迟 P50 / P95 / 均值 | **1320 / 5734 / 1726 ms** |
| 误触发 | **0 次**（静音合计 30 s + 段间静音，0 次/分钟） |
| 最大抢行 | 0 行（跳读段未越过未读行） |
| RTF | **0.0256**（x64 宿主，真机应更低） |
| 模型加载 | 433–483 ms |

## 3. 分段结果

| 片段 | CER | 命中率 | 首字 P95 | 跟随 P95 | 误触发 |
|---|---|---|---|---|---|
| zh_narrative | 6.3% | **50%** | 604 ms | **11060 ms** | 0 |
| zh_fast | 7.3% | 75% | 694 ms | 6774 ms | 0 |
| zh_skip | 7.1% | 66.7% | 614 ms | 5734 ms | 0 |
| zh_oral_filler | 3.3% | 80% | 1000 ms | 1946 ms | 0 |
| zh_number | 9.5% | 100% | 605 ms | 1872 ms | 0 |
| zh_repeat_repair | 8.5% | 100% | 598 ms | 1837 ms | 0 |
| zh_long_pause | 12.9% | 100% | 858 ms | 1558 ms | 0 |
| mix_brand | **22.4%** | 100% | 780 ms | 1320 ms | 0 |
| mix_term | **35.1%** | 100% | 495 ms | 2860 ms | 0 |
| silence | — | — | — | — | **0 次 / 30 s** |

## 4. 关键证据

### 4.1 中英混说是模型能力问题，不是参数问题

`mix_term` 识别结果（原文：Flutter / sherpa-onnx / SDK / JSON / prompt / REST / token / debug）：

```
这个功能依赖觉得插件体系底层是声音我们把音频留交给X第一由他返回的结果
前端需要单独配置不能写死在怠马里街口这边用的是瑞全走之后连吊的时候记得日
```

对应错法：`Flutter→觉得`、`sherpa-onnx→声音`、`SDK→X第一`、`JSON→结果`、`prompt→丢失`、`REST→瑞全`、`token→之后`、`debug→丢失`。14M 模型词表无英文 BPE，英文按整词精确匹配，**换任何解码参数都救不回来**。该段 CER 35.1%，是全部片段中最高。

### 4.2 归因：长句累积 + 置信度偏严导致「卡行」

`zh_narrative` 的滚动事件（`--dump`）：

```
1380ms  line=0 char=1  conf=1.00 same_line
...
5220ms  line=0 char=18 conf=1.00 same_line
6500ms  line=1 char=1  conf=1.00 line_step
6820ms  line=1 char=19 conf=0.27 same_line   ← 置信骤降
12260ms line=1 char=26 conf=0.46 same_line
24100ms line=3 char=15 conf=0.45 line_step   ← 直到 final 加成才跨行
```

- 第 1 行之后，识别文本在整个 utterance 内持续累积，对齐置信度从 1.00 掉到 0.27–0.46；
- 低于 `weakConfidence=0.35` 时不推进，高于 0.35 但不足 `confirmConfidence=0.55` 时需「弱命中 2 次」，实际卡住；
- 直到出现 final（+0.15 加成）才从 line1 直接跳到 line3，**中间两行被跳过**，命中率 50%、跟随 P95 11.06 s。

这不是「模型听错了」——同段 CER 只有 6.3%。是**置信度公式与闸门在长 utterance 上过严**，属于 P2/P3 的低成本修正对象。

### 4.3 端点阈值与跟随质量强相关

同样朗读，`zh_long_pause`（句间 1.8–2.4 s，会触发 2.4 s 端点重置）命中率 100%、跟随 P95 1.56 s；而 `zh_narrative`（句间 0.6–0.9 s，全段一个 utterance）命中率只有 50%。

说明：**端点越长 → 累积文本越长 → 置信度越低 → 越容易卡行**。把 `rule1` 从 2.4 s 降到 0.8–1.2 s 是零模型成本、可立即 A/B 的项；风险是短停顿处被切句、final 频繁导致闪烁，需用误触发与回跳指标守住。

### 4.4 当前不会在静音时乱滚

`silence` 段 30 s 纯静音 0 次推进；全部片段误触发 0 次/分钟，最大抢行 0 行。这是后续提高灵敏度的**红线**：任何调参/换模型都不能把它换掉。

### 4.5 首字延迟与分块下限吻合

首字延迟 P50 460 ms、P95 780 ms（音频轴，ASR 出字）。当前分块 shift 320 ms，叠加 20 ms 分片与解码耗时，与文档估算一致。**这部分不是模型大小能解决的**，要降只能改分块或做双流/低延迟解码。

## 5. 未能测的项目

| 项 | 原因 | 需要什么 |
|---|---|---|
| 真机 SM8750（骁龙 8 Elite）RTF / PSS / CPU | `adb install` 报 `INSTALL_FAILED_USER_RESTRICTED: Invalid apk`；设备未开启「USB 安装」 | 在开发者选项打开「USB 安装」（HyperOS 还需「USB 调试（安全设置）」），按 `eval/README.md` §5.3 重跑 |
| 真实麦克风端到端首字延迟 | 回放不经过 `record`、AGC/NS/AEC、`VOICE_RECOGNITION` | 真机 + 秒表/拍手 + 录屏逐帧对时 |
| 噪声/回声场景 | P0 无对应音频 | 舞台音箱、人群噪声各 2 段 |
| 方言口音 | 无真人录音 | 3 种口音 × 3–4 段 |
| 30/60 min 长跑、功耗、温升 | 宿主回放不能代表 | 真机长跑 + 电池脚本 |
| 真人语料 CER 绝对值 | 合成语音偏乐观 | 补齐 60 段真人集后重跑 |

## 6. 复现

```bash
cd teleprompter/tool/eval
flutter pub get
dart run gen_tts_set.dart --set ../../eval
dart run run_eval.dart \
  --model-dir ../../apps/app/assets/models/zipformer-zh-14M-int8 \
  --label host-macos \
  --out ../../build/eval-report.json

# 单段诊断（含滚动事件）
dart run run_eval.dart \
  --model-dir ../../apps/app/assets/models/zipformer-zh-14M-int8 \
  --only p0-zh-narr-01 --dump --out ../../build/tmp.json
```

## 7. 结论与下一步

1. **先修对齐/闸门与端点，再谈换模型**：4.2、4.3 两处都是零模型成本，且直接命中「不灵敏/跟不上」。
2. **中英混说必须换双语模型**（D1 已拍板），但换完仍要保留本基线做对照；14M 作为中文回退。
3. **误触发 0 是红线**：后续任何「更灵敏」的改动，都要在 `silence` 与 `zh_skip` 两段上不退化。
4. 真机数据缺口需先解决安装限制；在此之前，真机相关结论一律标注「需实测确认」。
