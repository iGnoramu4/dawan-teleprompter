# 架构说明

> 状态：生效 ｜ 责任人：TL ｜ 复核：每次架构变更 ｜ 更新：2026-11-12
> 与 [项目说明](../overview.md)、[计划文档](../../提词器项目落地计划.md) §7–§10 配套；本文只写结构与约束，不重复参数细节。

## 1. 架构风格

分层 + 模块化单体（Monorepo，多包）。三端共享 Dart 业务与 UI；平台能力经插件或 MethodChannel 下沉到原生。核心算法（模型、对齐、阅读布局、录制时间轴）为纯 Dart，可脱离 Flutter 单测。

## 2. 模块划分

| 包 / 目录 | 职责 | 依赖 | 是否含 Flutter |
|---|---|---|---|
| `core_models` | 台本、分段、标记、预设等不可变模型；`.tps` 包格式 | 无 | 否 |
| `core_alignment` | 归一化、拼音、模糊等价、预筛、窗口单调 DP、闸门、跳读预算 | `core_models`、`lpinyin` | 否 |
| `core_reader_layout` | 视觉行快照、固定阅读带、`ReadingFollower` 逐行吸附与冻结 | `core_models` | 否 |
| `core_scroll` | 独立弹簧滚动规划（历史包；阅读页已改用 `core_reader_layout`） | `core_models` | 否 |
| `core_recording` | 录制时间轴：10 Hz 采样、线性插值、SRT 导出 | `core_models` | 否 |
| `data_store` | drift schema、仓储、迁移、断点、`.tps` 导入导出 | `core_models`、`drift`、`sqlite3` | 否（IO） |
| `asr_kit` | sherpa-onnx 封装、麦克风采集、模型解包/切换、WAV 回放 | `core_models`、`sherpa_onnx` | 是（插件） |
| `design_system` | Material 3 主题、令牌、通用组件、`StagePalette` | Flutter | 是 |
| `overlay_bridge` | 主引擎 ↔ 悬浮窗引擎的 JSON 消息桥 | 无 | 否（仅 Android） |
| `apps/app` | 装配、路由、feature 页面、共享状态与平台桥 | 全部 | 是 |

> `apps/app/lib/utils/document_import.dart` 负责 TXT/MD/DOCX/PDF 解析；`lib/shared/remote/` 与 `lib/data/lan_transfer.dart` 负责局域网遥控与互传；`lib/data/app_log.dart` 与设置页负责日志与诊断导出。它们目前是应用层模块，没有单独拆包。

## 3. 依赖方向（必须无环）

```
                      apps/app
   ┌──────────┬──────────┼───────────┬──────────────┐
   ▼          ▼          ▼           ▼              ▼
features   shared   design_system  asr_kit     data_store
   │          │                        │             │
   └──────────┴────────────┬───────────┴─────────────┘
                           ▼
             core_alignment / core_reader_layout
                  / core_recording / core_scroll
                           │
                           ▼
                       core_models
```

规则（`tool/check_imports.dart` 强制）：

1. `core_*` 不得 import Flutter、`dart:ui` 或任何插件；
2. `core_alignment` / `core_reader_layout` / `core_scroll` / `core_recording` 只能依赖 `core_models` 等纯 Dart 包；
3. `features/<a>` 不得 import `features/<b>`（跨 feature 必须下沉到 `packages/` 或 `apps/app/lib/shared/`）；
4. `lib/shared/` 不得反向 import `features/`；
5. `packages/*` 不得 import 应用代码（`package:teleprompter/` 或跳出包 `lib` 的相对路径）；
6. `design_system` 不得依赖业务包（`data_store`、`asr_kit`、`core_*`）；
7. 原生层不得反向调用业务 Dart。

## 4. 会话与健康状态

阅读页与 `VoiceFollowSession` 的对外状态：

```
idle ──start──► loading ──ready──► following ⇄ paused
                  │                   │
                  └──error──► error ◄─┘（麦克风失败 / 模型缺失 / 权限拒绝）
```

- 手动接管：`following → manual`（手势 / 遥控），无语音或用户恢复后回到 `following`；
- 低置信：在 `following` 内降速，不切状态；连续多次低置信回到手动并提示；
- 对齐失败（`matched=false`）只冻结滚行，识别文本与状态角标继续刷新；
- 状态变化只经由 `Notifier`，UI 不直接改状态。

## 5. 关键数据流

### 5.1 台本导入 → 编辑

```
外部文件 / 剪贴板 / .tps
  → document_import（格式嗅探、大小限制）
  → 清洗（页眉页脚、硬换行、全半角、Markdown）
  → 预览确认（用户可调）
  → data_store 事务写入 scripts / sections / markers / presets
  → 归一化缓存（拼音/索引，可重建）
```

### 5.2 提词 → 识别游标

```
麦克风 (16 kHz / mono / PCM16)
  → asr_kit 流式识别（partial / final + 端点）
  → core_alignment：
       归一化 → 拼音音节 → 命中率预筛 → 窗口单调 DP
       → 整行读音覆盖度闸门 → AlignTracker / AutoAdvanceBudget
  → core_reader_layout：
       视觉行坐标 → 固定阅读带目标 → ReadingFollower 逐行吸附
  → Renderer：单处 Transform.translate + 固定带指示（不触发文本重排）
  → 诊断记录指标（不记识别原文）
```

### 5.3 遥控 / 多设备

```
主控端（渲染端）分配语义行号 + 视觉行坐标
  → remote 协议 v3 广播（anchorLine + anchorOffset + anchorRow + layoutVersion）
  → WebSocket（局域网、配对 token、默认关闭）
  → 遥控端只显示行号/文本切片，不做像素换算
  → 命令上行 cmd → 主控执行 → ack
```

### 5.4 录制与复盘

```
同一 PCM 流扇出（禁止二次打开麦克风）
  → 录音文件 + 10 Hz 时间轴（t → 段落/字符）
  → 回放时按播放位置驱动同一 ReaderState
```

## 6. 边界与失败策略

| 边界 | 失败表现 | 处理 |
|---|---|---|
| 麦克风权限 | `PermissionDenied` | 切匀速滚动 + 提示 + 可重试 |
| 模型缺失/校验失败 | `Unavailable` | 禁止开始跟随，引导导入/重装 |
| ASR 初始化失败 | `Unavailable` | 尝试低档模型；仍失败则手动模式 |
| 对齐置信度低 | 非错误 | 降速、回退手动，不崩溃 |
| 解包失败 | `ModelInstallException` | 删除半成品目录，提示重试；`cleaned=false` 提示检查存储 |
| 数据库迁移失败 | `StorageFailure` | 自动还原备份，提示导出诊断包 |
| 网络关闭/端口占用 | `NetworkFailure` | 遥控不可用，其他功能不受影响 |
| 外接屏拔出 | 非错误 | 回退主屏并提示 |

## 7. 扩展点

- 新 ASR 引擎：在 `asr_kit` 内封装为新的 `AsrEngine` 实现，并保持 `VoiceFollowSession` 的输入输出契约；
- 新导入格式：在 `apps/app/lib/utils/document_import.dart` 增加解析分支与 MIME 白名单；
- 新语言：新增 ARB + 可选模型档，不改动对齐核心；
- 新平台（iOS/Linux）：新增平台桥或插件，业务层不改。

## 8. 通道契约（摘要）

| 通道 | 方法 | 入参 | 返回/事件 |
|---|---|---|---|
| `tps/display` | `listDisplays` / `present` / `update` / `dismiss` | `displayId`、`fontSize`、`mirrored`、`bandRatio` | 显示器列表；事件 `displayRemoved` |
| `com.tp.prompter.teleprompter/platform` | `notificationStatus` / `requestNotification` / `startVoiceService` / `stopVoiceService` | 无 | `bool` / `void` |
| `com.tp.prompter.teleprompter/overlay_bridge` | 主引擎 ↔ 悬浮窗引擎 JSON 消息 | `lines`、`anchor`、`lineCount`、`opacity`、`widthDp`、`fontSize` | 浮窗控制与内容更新 |

悬浮窗由 `flutter_overlay_window` 创建独立 FlutterEngine，`overlay_bridge` 在两条引擎之间转发 JSON；桌面端无对应实现，统一静默降级。契约变更必须版本化并在本文更新。

## 9. 相关文档

- [项目说明](../overview.md)：功能、跟随原理、构建、资源、测试与限制
- [编码规范](../standards/CODING.md) ｜ [原生规范](../standards/NATIVE.md) ｜ [国际化](../standards/I18N.md)
- [遥控协议](../api/remote-protocol.md) ｜ [外接显示通道](../api/display-channel.md) ｜ [录制时间轴](../api/recording-timeline.md)
- [ADR](./adr/README.md)：框架、ASR 引擎、开源许可、体积与字体、性能基准
