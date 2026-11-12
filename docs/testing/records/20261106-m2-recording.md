# M2 测试记录：录制 + 时间轴 + 复盘 + 导出（E8-1/E8-2/E8-3）

> 阶段：M2 ｜ 构建：`0.17.0+2020` ｜ 日期：2026-11-06
> 目的：验证录制写入 WAV、10 Hz 行号采样、时间轴插值与 SRT 导出、复盘控制、录制历史面板与删除级联；真实麦克风采集、系统权限弹窗与真机音频回放不在本轮验证范围。
> 权限登记见 [permissions.md](../../permissions.md)；依赖评估见 [DEPENDENCY_POLICY §10](../../process/DEPENDENCY_POLICY.md)。

## 1. 环境

| 项 | 值 |
|---|---|
| 主机 | macOS（arm64），Flutter `3.47.9` stable |
| Dart 测试 | `flutter test`（163 项），音频采集/播放使用 fake 注入，不打开真实麦克风与播放器 |
| 数据库 | drift 内存库；`schemaVersion` 1→2 迁移路径由 `onUpgrade` 建表 |
| 设备 | 无；未在模拟器/真机实际录制与回放 |
| E8-4 | 未实现：计划中为桌面可选的 whisper 对齐，仓库内无模型与构建脚本，本轮不引入 |

## 2. 用例

### 2.1 纯 Dart 时间轴与 SRT（`packages/core_recording/test`）

| 用例 ID | 场景 | 结果 | 备注 |
|---|---|---|---|
| REC-01 | 时间轴 JSON 往返、版本不支持/缺 `scriptId`/坏 JSON 拒绝 | 实测通过 | `tryDecode` 返回 null |
| REC-02 | 锚点线性插值、越界夹到首尾、重复时间戳不除零 | 实测通过 | 250 ms → 3 行 |
| REC-03 | 10 Hz 采样、过密丢弃、负数归一化、结束时间不早于最后采样 | 实测通过 | 自定义间隔 500 ms |
| REC-04 | 按"停留行"生成 SRT，换行折叠、越界行/零时长跳过、小时超两位 | 实测通过 | `99:59:59,999` 格式 |

### 2.2 WAV 与录制控制器（`test/wav_writer_test.dart`、`test/recording_controller_test.dart`）

| 用例 ID | 场景 | 结果 | 备注 |
|---|---|---|---|
| REC-05 | 写入 Float32 生成合法 RIFF/WAVE 头、数据长度、±1 裁剪、NaN 容错 | 实测通过 | 16 kHz/单声道/16 bit |
| REC-06 | 空分片、重复 close 幂等、abort 删除半成品 | 实测通过 | 44 字节空文件 |
| REC-07 | 外部 PCM 流入 + 定时采样，停止后落库并写出 WAV/时间轴 | 实测通过 | 文件大小与库记录一致 |
| REC-08 | 取消录制删除文件且不落库；未开始录制时 stop/cancel/dispose 安全 | 实测通过 | 半成品清理 |

### 2.3 复盘、导出与面板（`test/replay_controller_test.dart`、`test/recording_export_test.dart`、`test/recording_history_sheet_test.dart`）

| 用例 ID | 场景 | 结果 | 备注 |
|---|---|---|---|
| REC-09 | 播放位置按时间轴插值回调行号、进度 0–1、seek 负数夹 0 | 实测通过 | `ReplayAudio` fake |
| REC-10 | 加载失败返回 false 并回调错误；时间轴缺失/损坏回退空轴仍可播放 | 实测通过 | 不阻断阅读页 |
| REC-11 | 导出 WAV + `timeline.json` + `captions.srt`，音频缺失时导出 2 个文件 | 实测通过 | 文件名 `tps-YYYYMMDD-HHMMSS` |
| REC-12 | 保存器异常上抛、用户取消停止后续导出 | 实测通过 | 调用方提示 |
| REC-13 | 历史面板渲染列表/时长/大小，复盘关闭、导出、删除确认后刷新、空态 | 实测通过 | 5 项 widget 测试 |

### 2.4 数据库（`packages/data_store/test/repository_test.dart`）

| 用例 ID | 场景 | 结果 | 备注 |
|---|---|---|---|
| REC-14 | 录制写入/按台本倒序读取/最近一条/timelineJson 透传 | 实测通过 | schema v2 |
| REC-15 | 删除单条录制同时删除音频文件；重复删除返回 null | 实测通过 | 文件已不存在时忽略 |
| REC-16 | 永久删除台本级联删除录制与音频文件 | 实测通过 | `deleteForever` |

## 3. 覆盖率与四检

- 全量：`flutter test --coverage` **163 项全部通过**；覆盖率 **81.6%（2704/3315 行）** ≥ 70%。
- `dart format --set-exit-if-changed`：0 变更；`dart analyze --fatal-infos --fatal-warnings`（app / data_store / core_recording）：无问题；`check_imports`：OK。
- 覆盖率下降原因：新增阅读页录制/复盘 UI（按钮、状态条、复盘条）大部分分支依赖真实采集与播放器，宿主测试未覆盖；新增纯逻辑均有单测，未下调阈值、未排除文件。

## 4. 未自动化 / 未验证

| 项 | 原因 | 替代验证 |
|---|---|---|
| 真实麦克风采集与系统权限弹窗 | 宿主测试注入 PCM 流，避免系统级弹窗 | 真机/桌面首次点「录制」回归（Android `RECORD_AUDIO`、macOS TCC、Windows 隐私开关） |
| 语音跟随与录制共用麦克风的真实并发 | fake 流仅验证转发接口 | 真机开启跟随后再录制，确认无两路采集冲突 |
| Android / macOS 音频回放 | 无设备与播放环境 | 真机复盘：播放/暂停/拖动/倍速与稿件联动 |
| Windows 复盘播放 | `just_audio` 无 Windows 官方实现 | 已接入异常提示降级；后续可评估 `just_audio_windows` |
| 音频与画面长期同步漂移 | 需真实录制 ≥10 min | 真机长录后按时间轴抽查行号偏差 |
| 导出「另存为」在 Android SAF 的实际落盘 | 需要系统文件选择器 | 真机分别导出三类文件并校验可打开 |
| APK 包体增量（just_audio / WAV 无解码器） | 未打包完整 APK | 发布构建时记录 |
| E8-4 whisper 离线对齐 | 桌面可选，缺模型与构建脚本 | 本轮不引入；M2 其余交付不受影响 |

## 5. 结论

- 实测通过（宿主）：时间轴/SRT/WAV/导出/复盘控制/录制控制器/数据库/历史面板全部自动化用例。
- 仅接入未验证：真实麦克风与权限弹窗、真机音频回放、三端文件保存、长录制同步、Windows 复盘（降级提示）、包体增量。
- 权限与依赖已登记：`docs/permissions.md`（Android `RECORD_AUDIO`、macOS/Windows 麦克风）、`DEPENDENCY_POLICY §10`、`NOTICE §6`；`core_recording` 为自研纯 Dart 包。
- 契约文档：`docs/api/recording-timeline.md`（WAV 参数、`timeline.json` v1、插值与 SRT 规则）。
- 说明：`提词器项目落地计划.md`/`提词器项目规划方案.md` 为只读约束文件，本次未修改；本轮未触发任何 sudo/管理员密码或系统级授权弹窗。
