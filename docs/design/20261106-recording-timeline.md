# 录制 + 时间轴设计（E8-1 / E8-2）

> 状态：reviewed ｜ 责任人：FE ｜ 更新：2026-11-06 ｜ 适用：`0.17.0+2020`
> 目的：说明录制、时间轴采样、复盘联动的数据流与取舍；字段级契约见 [recording-timeline.md](../api/recording-timeline.md)。

## 1. 目标与约束

- 录制时音频与"当前行号"并行落盘，事后可按音频位置回放稿件；
- 不新增第二路麦克风采集：语音跟随已开麦时复用同一条 PCM 流（计划 §10.6）；
- 不引入自研编码器：WAV 为 PCM，写盘流式回填头，避免整段音频进内存；
- 录制/复盘失败不得阻断阅读与提词；无播放器平台（Windows）降级提示；
- 纯逻辑（时间轴、插值、SRT）必须可离线单测，放在 `packages/core_recording`（无 Flutter 依赖）。

## 2. 数据流

```text
麦克风 ──► AudioCapture 16 kHz PCM ──┬─► VoiceFollowSession（识别/对齐）
                                     └─► RecordingController.feed ──► PcmWavWriter
                                                                         │
阅读页锚点 ──► 100 ms Timer ──► TimelineBuilder.sample ──► RecordingTimeline
                                                                         │
stop() ──► readings 写入 recordings 表（WAV 路径 + timelineJson + 时长/大小）──► 录制历史
                                                                         │
复盘 ──► just_audio 播放 ──► positionStream ──► anchorAt(ms) ──► 阅读页跳行
```

- 录制控制器按 `tickInterval=100 ms` 采样锚点；停止时补最后一条采样与总时长；
- 采样与音频无共享时钟，`t` 以控制器启动为 0，允许 <100 ms 量化误差；
- 复盘按播放位置查时间轴，线性插值后 `round` 到行号；轴缺失时只播放、不联动。

## 3. 存储与生命周期

- 音频：应用私有目录 `recordings/rec-<epochMs>-<seq>.wav`；
- 数据库：`recordings` 表（schemaVersion 2），`timeline_json` 可空；
- 删除：单条删除先删记录再删文件；永久删除台本在事务内收集路径，事务后删除音频；
- 取消录制：关闭写入器并删除半成品，不落库；
- 崩溃/强杀：文件头未回填，文件不可播放；当前不做启动时孤儿文件清理（已知限制）。

## 4. 关键取舍

| 决策 | 备选 | 取舍理由 |
|---|---|---|
| PCM WAV 16 kHz 单声道 | AAC/Opus 编码 | 与 ASR 输入一致；无编码器依赖、无授权成本；体积大但只存本机 |
| 10 Hz 采样 | 每帧/事件驱动 | 行号变化远慢于帧率；100 ms 量化足够，数据量小 |
| 线性插值 | 阶梯/最近邻 | 复盘跳行更平滑；实现可离线单测 |
| 按"停留行"生成 SRT | 按标点断句 | 导出结果与提词行一致，不引入 NLP 分词 |
| `just_audio` 复盘 | `audioplayers` | 社区维护活跃、位置流完整；Windows 无官方实现已降级 |
| 复用语音跟随 PCM | 独立 `record` 流 | 避免双路采集冲突与 Android 前台服务复杂度 |

## 5. 失败路径

| 场景 | 行为 |
|---|---|
| 麦克风授权拒绝/启动失败 | `AudioCaptureException` → 提示权限不足；不进入录制态 |
| 写盘失败 | `onError` 回调提示，停止录制并尽力清理半成品 |
| 语音跟随开启中录制 | `useMic=false`，仅转发 PCM；关闭跟随时自动停止录制 |
| 录制中开启跟随/演示回放 | 阻断并提示"录制进行中" |
| 复盘加载失败 | 提示失败并退出复盘条，稿件保持当前锚点 |
| `timeline.json` 损坏/版本不符 | `tryDecode` 返回 null，仍可播放音频 |
| Windows 复盘 | 播放器不可用 → 提示该平台暂不支持 |

## 6. 测试计划

- 纯 Dart：`core_recording/test/recording_timeline_test.dart`（JSON/插值/采样/SRT）；
- 控制器：`wav_writer_test.dart`、`recording_controller_test.dart`（外部流、取消、裁剪）；
- 复盘/导出：`replay_controller_test.dart`、`recording_export_test.dart`；
- UI/数据：`recording_history_sheet_test.dart`、`repository_test.dart`（级联删除）；
- 真机验收：系统授权弹窗、跟随+录制并发、≥30 min 长录偏差、Android SAF 落盘、Windows 降级提示。

## 7. 回滚

- 功能级：关闭阅读页录制/历史入口即可，已有音频文件与 `recordings` 表不影响阅读；
- 数据级：schemaVersion 2 只新增表与索引，旧版本读取不受影响；如需回退版本，保留 `recordings` 表即可。
