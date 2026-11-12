# 录制时间轴与导出格式契约

> 状态：reviewed ｜ 责任人：FE ｜ 更新：2026-11-10 ｜ 适用：`0.22.0+2025`
> 目的：定义 M2 录制产物（WAV / `timeline.json` / SRT）的字段、插值规则与导出行为（计划 E8-1..E8-3）。
> 实现：`packages/core_recording`（纯 Dart）+ `apps/app/lib/shared/recording/`。

## 1. WAV 音频

| 项 | 值 |
|---|---|
| 容器 | RIFF/WAVE，44 字节 PCM 头 |
| 编码 | PCM 16 bit，little-endian |
| 采样率 | 16000 Hz |
| 声道 | 1（单声道） |
| 样本范围 | Dart 侧 `Float32List`，写入前裁剪到 `[-1, 1]` 并放大 32767 |
| 写盘方式 | 先占位 44 字节头，追加写数据；`close()` 回填 RIFF/data 长度 |
| 中止 | `abort()` 关闭句柄并删除半成品文件 |

- 文件位于应用私有目录 `recordings/rec-<epochMs>-<seq>.wav`，不写入外部存储。
- 语音跟随已开麦时复用同一条采集流，不重复打开麦克风（计划 §10.6）。

## 2. `timeline.json` v2

```json
{
  "version": 2,
  "scriptId": "sc-...",
  "durationMs": 12345,
  "samples": [
    {"t": 0, "anchor": 0, "char": 0},
    {"t": 100, "anchor": 0, "char": 7, "conf": 0.82}
  ]
}
```

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `version` | int | 否（缺省按 2） | 接受 `1`、`2`；其他值视为不兼容 |
| `scriptId` | string | 是 | 所属台本 id，不能为空 |
| `durationMs` | int | 否 | 录制总时长；缺省取最后一个采样的 `t`，负值归零 |
| `samples[].t` | int | 是 | 相对录制开始的毫秒数，升序 |
| `samples[].anchor` | int | 是 | 当前段落号（0 基）；v2 起语义行 = 段落 |
| `samples[].char` | int | 否（缺省 0） | v2 新增：段内字符偏移（归一化前原文） |
| `samples[].conf` | double | 否 | 语音跟随置信度；为 0 时序列化省略 |

采集规则（`TimelineBuilder`）：

- 固定 10 Hz（`intervalMs = 100`），由录制控制器按 100 ms 节拍喂入当前锚点与段内字符偏移；
- 负数 `t` / `anchor` / `char` 归零；与上一条间隔不足 100 ms 的采样丢弃；
- `durationMs` 不早于最后一条采样时间。

解析容错：`RecordingTimeline.tryDecode` 对坏 JSON / 版本不符 / 缺 `scriptId` 返回 `null`，复盘入口仍然可用（只播放、不联动稿件）；`fromJson` 则抛 `FormatException`。

## 3. 位置插值

`positionAt(ms)` 返回 `({int line, int char})`，用于复盘时把音频位置映射回「段落 + 段内字符」：

- 空时间轴 → `(0, 0)`；
- `ms` 不晚于首采样 → 首采样 `(anchor, char)`；不早于末采样 → 末采样 `(anchor, char)`；
- 区间内二分查找相邻采样，行号与同段内的 `char` 均线性插值后四舍五入（`round`）；
- 相邻采样跨段时 `char` 取两端端点值，不做跨段插值（避免落到不存在的偏移）；
- 相邻采样 `t` 相同 → 取后者。
- `anchorAt(ms)` 保留为 `positionAt(ms).line` 的兼容入口。

## 4. SRT 字幕

`TimelineSrtExporter.build(lines, timeline)`：

- 按「停留行」切段：连续采样 `anchor` 不变的区间为一条字幕，切点在 `anchor` 首次变化处；
- 起始时间为该段首采样 `t`，结束时间为下一段的起始时间（末段用 `durationMs`）；
- 时间格式 `HH:MM:SS,mmm`（小时不截断到 24）；
- 跳过越界行号、零时长段与空白行；行内连续空白折叠为单个空格；
- 空台本或空时间轴返回空字符串。
- 0.22.0 起阅读页导出时传 `captionLines = 视觉行` 与 `captionIndex = rowForChar`，先把「段落 + 段内字符」折算成视觉行号再生成字幕；`timeline.json` 本身仍保存原文（段落 + 字符）坐标，不写视觉行。

## 5. 导出行为

- 文件基名 `tps-YYYYMMDD-HHMMSS`（录制创建时间的本地时区）；
- 依次导出 `<base>.wav`（音频存在时）、`<base>.timeline.json`、`<base>.captions.srt`；
- 走系统「另存为」（Android SAF）；用户取消即停止后续文件，返回已保存数量；
- 单文件写入异常向上抛出，由界面提示失败。

## 6. 数据库映射

`recordings` 表（schemaVersion 2）：

| 列 | 说明 |
|---|---|
| `id` / `scriptId` / `sessionId?` | 录制标识与所属台本 |
| `path` | WAV 绝对路径 |
| `durMs` | 总时长 |
| `timelineJson?` | 本文档第 2 节 JSON 文本；可为空（仅音频） |
| `createdAt` / `sizeBytes` | 创建时间与文件大小 |

永久删除台本时级联删除记录与音频文件。

## 7. 兼容性

- `version` 递增必须同步本文件与 `CHANGELOG`；读取端遇到更高版本应降级为「仅播放」而不是崩溃。
- v1 → v2：读取端接受 `version` 为 `1` 或 `2`；v1 采样无 `char`，按 `0` 处理。由于 0.22.0 起语义行 = 段落，阅读页在回放/导出前用 `mapLegacyAnchorToParagraphs` 把 v1 的旧句行号迁移为「段落 + 段内字符」，再传给 `ReplayController`/`exportRecording`。旧版按窗口宽度自动切行的录制无法精确还原，迁移为近似值（不越界）。
- `anchors` 语义变更：v2 起 `anchor` 是段落号，旧播放器把 v2 文件当 v1 读时仍安全（只播放、不联动稿件），不会崩溃。
- 新增可选字段可向后兼容；重命名/删除既有字段属于破坏性变更，需新增版本号。
- WAV 参数（16 kHz / 单声道 / 16 bit）与 ASR 共用；变更需评估语音跟随链路与 Android 前台服务约束。
