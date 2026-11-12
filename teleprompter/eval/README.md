# ASR / 跟随评测集（P0）

> 状态：P0 可运行 ｜ 更新：2026-11-10 ｜ 对应规范：[docs/testing/TESTING.md](../../docs/testing/TESTING.md) §5
>
> 目的：把「更灵敏」「更跟手」变成可复现的数字，而不是手感。**本目录不参与产品构建。**

## 1. 目录结构

```
eval/
├── README.md              本文件（设计、许可、运行方法）
├── manifest.json          资产清单：片段 id / 类别 / 标注 / 音频 / 来源 / 许可
├── scripts/p0/*.json      台本与合成参数（单一事实来源）
├── labels/*.json          逐行时间标注（由 scripts 生成）
└── audio/*.wav            16 kHz / 单声道 / PCM16（由 scripts 生成，不入库）
```

- 台本与标注**入库**；音频可用 `tool/eval/gen_tts_set.dart` 复现。
- 音频格式固定 16 kHz、单声道、PCM16，与产品采集链路一致。
- 标注与音频同 id，一行对应台本的一个语义行（段落）。

## 2. 评测集设计

### 2.1 P0（当前可跑，10 段合成语音）

| id | 类别 | 考察点 |
|---|---|---|
| `p0-zh-narr-01` | zh_narrative | 普通叙述基准：CER、首字延迟、跟随延迟 |
| `p0-zh-oral-01` | zh_oral_filler | 呃/那个/就是说/嗯：插入词对置信度与对齐的影响 |
| `p0-zh-repeat-01` | zh_repeat_repair | 重复与自我纠正（「不对，我重新说」）：回跳抑制 |
| `p0-zh-number-01` | zh_number | 百分比、金额、日期：数字读法归一化 |
| `p0-mix-term-01` | mix_term | Flutter / sherpa-onnx / SDK / JSON / prompt：中英混说 |
| `p0-mix-brand-01` | mix_brand | iPhone / Wi-Fi / AI：品牌名与缩写 |
| `p0-zh-fast-01` | zh_fast | 无标点长句、快语速：连续推进能力 |
| `p0-zh-pause-01` | zh_long_pause | 1.8–2.4 s 长停顿：端点检测边界 |
| `p0-zh-skip-01` | zh_skip | 台本里有一行未读：是否抢行/跳到下一行 |
| `p0-silence-01` | silence | 30 s 纯静音：误触发基线 |

> P0 合成段长 19–32 s（便于快速回归）；真人集按 TESTING §5.1 的 60–120 s 录制。

### 2.2 全量（60 段，按 TESTING §5.1 配额补齐）

| 类别 | 段数 | 现状 |
|---|---|---|
| 普通话男声 | 12 | P0 用合成女声替代，男声待真人录制 |
| 普通话女声 | 12 | P0 已覆盖 8 段（合成） |
| 方言口音 | 10 | 待真人录制 |
| 中英混读 | 8 | P0 已覆盖 2 段（合成） |
| 含口误/重复/甩词 | 8 | P0 已覆盖 1 段（合成） |
| 含跳读/插话 | 6 | P0 已覆盖 1 段（合成） |
| 噪声/回声 | 4 | 待采集（舞台音箱、人群噪声） |

补齐方式：把真人录音放到 `audio/`，标注放到 `labels/`，在 `manifest.json` 增加条目并置 `"status": "ready"`。合成条目与真人条目在报告中通过 `source` 字段区分。

### 2.3 标注格式

```json
{
  "id": "p0-zh-narr-01",
  "durationMs": 28400,
  "lines": [
    { "index": 0, "text": "各位好，今天这场分享我们主要讲三个部分。", "startMs": 600, "endMs": 5220, "spoken": true }
  ]
}
```

- `startMs` / `endMs`：该行实际发声区间，用于算首字延迟与跟随延迟。
- `spoken: false`：该行在台本里但未读出（跳读），不计入命中率，但可用于检测抢行。

## 3. 指标口径

| 指标 | 计算方式 | 目标（TESTING §5.2） |
|---|---|---|
| CER | 归一化后按 token 编辑距离 / 参考 token 数（中文按字、英文按词） | 无门禁，作为对照 |
| 首字延迟 | 每行开始 → 第一条包含新内容的 ASR 结果到达（音频时间轴） | P95 ≤ 800 ms（端到端首字 ≤ 500 ms 另算） |
| 跟随延迟 | 每行开始 → 锚点首次到达该行（含闸门/early arm） | 越低越好，当前无门禁 |
| 跟随命中率 | 每行结束 +600 ms 时锚点是否 ≥ 该行 | ≥ 95%（真人集） |
| 误触发/分钟 | 静音区间内锚点越过「已读行」的次数 / 静音分钟数 | < 1 次/30 min |
| 抢行 | 任一时刻 `锚点行 − 应读行` 的最大值 | 不应出现明显抢行 |
| RTF | 解码总耗时 / 音频时长 | 单核 < 0.5（实时余量 2×） |
| 内存 | 评测进程 RSS 增量 | 结合真机 `dumpsys meminfo` |

> 说明：`首字延迟` 与 `跟随延迟` 都是**音频时间轴**上的差值，不含麦克风采集到 Dart 的缓冲；端到端数字需真机实测另行记录。

## 4. 许可与版权

- P0 音频全部由 macOS `say`（Tingting）合成，**不含第三方录音版权**，条目 `license` 标注 `self-generated (macOS say), no third-party audio`。
- 真人录音必须自录或取得书面授权，授权书编号写入 `manifest.json` 的 `license` 字段；第三方素材（有声书、播客、影视）**不得入库**。
- 音频不包含真实姓名、账号、设备标识；台本为虚构内容。
- 音频文件默认不入 Git（可用脚本复现）；如需归档，记录来源与授权。

## 5. 运行方法

### 5.1 生成合成音频（macOS）

```bash
cd teleprompter/tool/eval
flutter pub get
dart run gen_tts_set.dart --set ../../eval          # 已存在则跳过
dart run gen_tts_set.dart --set ../../eval --force  # 强制重建
```

### 5.2 宿主跑基线（当前环境已跑通）

```bash
cd teleprompter/tool/eval
dart run run_eval.dart \
  --model-dir ../../apps/app/assets/models/zipformer-zh-14M-int8 \
  --label host-macos \
  --out ../../build/eval-report.json
```

常用开关：

| 参数 | 用途 |
|---|---|
| `--only <id 子串>` | 只跑某段（配合 `--dump` 看逐条滚动事件） |
| `--chunk-ms 20` | 音频分片粒度，默认 20 ms |
| `--decoding greedy_search\|modified_beam_search` | 解码方法 A/B |
| `--rule1/--rule2/--rule3` | 端点检测三阈值 A/B |
| `--threads` | 解码线程数 A/B |

输出：终端逐段摘要 + `build/eval-report.json`（含每段明细与分类汇总）。

### 5.3 真机跑（骁龙 8 Elite / SM8750）

前置：Android 开发者选项里打开 **「USB 安装」**（部分机型叫「通过 USB 安装」，MIUI/HyperOS 还需「USB 调试（安全设置）」）。未打开时 `adb install` 会报 `INSTALL_FAILED_USER_RESTRICTED`。

```bash
# 1) 设备准备（模型与音频不随包，走应用私有外部目录）
DEV=<device-id>
PKG=com.dawan.teleprompter.eval_device
adb -s $DEV shell mkdir -p /sdcard/Android/data/$PKG/files/models
adb -s $DEV push teleprompter/eval /sdcard/Android/data/$PKG/files/eval
adb -s $DEV push teleprompter/apps/app/assets/models/zipformer-zh-14M-int8 \
  /sdcard/Android/data/$PKG/files/models/

# 2) 构建并安装 harness（profile，避免 debug JIT 失真）
cd teleprompter/tool/eval_device
flutter build apk --profile --target-platform android-arm64 \
  --dart-define=EVAL_DIR=/sdcard/Android/data/$PKG/files/eval \
  --dart-define=MODEL_DIR=/sdcard/Android/data/$PKG/files/models/zipformer-zh-14M-int8 \
  --dart-define=RUN_LABEL=android-sm8750
adb -s $DEV install -r build/app/outputs/flutter-apk/app-profile.apk

# 3) 运行并采集
adb -s $DEV logcat -c
adb -s $DEV shell am start -n $PKG/.MainActivity
adb -s $DEV logcat -s flutter | grep '\[eval\]'

# 4) 取回报告
adb -s $DEV pull /sdcard/Android/data/$PKG/files/eval/device-report-android-sm8750.json \
  teleprompter/build/
```

真机额外要记录（脚本不覆盖的部分）：

- `adb shell dumpsys meminfo $PKG` 的 PSS；
- `adb shell top -H -p <pid>` 的 CPU；
- 连续 30 min 播放的耗电与温升；
- 真实麦克风的端到端首字延迟（用拍手/秒表 + 录屏逐帧对时）。

## 6. 已知限制

1. **合成语音 ≠ 真人分布**：TTS 无口音、无环境噪声、语速稳定，CER 会偏乐观；只能做版本间相对比较。
2. **回放不是采集**：不经过 `record` 插件、AGC/NS/AEC 与 `VOICE_RECOGNITION` 音频源，测不到前端与缓冲的真实影响。
3. **宿主为 x64 Dart VM（Rosetta）**：RTF 仅作数量级参考，绝对性能以真机为准。
4. 对齐/闸门是**离线复刻**（`lib/follow_sim.dart`），与 `reader_page.dart` 保持同一套 `core_alignment` 参数；若产品逻辑变更需同步。
