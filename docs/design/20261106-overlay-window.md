# 系统级悬浮提词（Android）设计

> 范围：`apps/app/lib/features/reader/overlay/`、`packages/overlay_bridge/` 与 Android `OverlayService` / `VoiceService`。状态：生效 ｜ 维护：FE ｜ 更新：2026-11-10（`0.22.0+2025`，视觉行切片 + `anchorRow`、功能栏可隐藏）
> 对应计划：W-02（基础能力）、W-03（样式与同步）、E5-1。

## 1. 目标与本期边界

**已实现**
- 在其他 App、桌面或分屏上方显示提词行；当前行高亮，上下行半亮。
- 3 行 / 5 行两种可见行数（全稿模式已下线）；窗口宽度、不透明度可调，实时生效。
- 窗口始终自动跟随当前行：锚点前进时窗口内行内容整体上移，不存在「仅高亮、需手工翻动」的形态。
- 悬浮窗内的开始/暂停、上一行/下一行、锁定/解锁、麦克风开关与主阅读页双向同步。
- 收音角标（加载中/收音中/静音/低置信/后台）随主页面状态显示。
- 原生拖拽移动、位置记忆（dp）、关闭按钮；关闭后主页面状态、阅读进度保持一致。
- 首次开启的权限说明与系统设置跳转；悬浮权限、通知权限被拒均有提示与降级。
- 麦克风前台服务 `VoiceService`，让收音在退到后台后仍有前台服务凭据。

**未实现（后续）**
- 悬浮态锚点由「主引擎 ASR」驱动：主 Activity 退后台后能否持续推进，取决于系统是否限制定时器/音频回调（见 §6）。
- Windows 分层窗、macOS `NSPanel`（平台不同，另行设计；本轮不做）。
- 悬浮窗点击穿透、手势锁定以外的窗口级手势（`OverlayFlag` 相关）。

## 2. 权限与降级

| 步骤 | 行为 |
|---|---|
| 点击阅读页「悬浮提词」 | `FlutterOverlayWindow.isPermissionGranted()`（`SYSTEM_ALERT_WINDOW`） |
| 未授权 | 弹说明对话框（为什么、拒绝会怎样）；「去授权」跳 `ACTION_MANAGE_OVERLAY_PERMISSION` |
| 从系统设置返回 | 再次查询权限；成功则继续，失败则 Snackbar「未获得悬浮窗权限，已保留应用内提词」 |
| 已授权 | 继续显示流程 |
| 显示前 | 检查 `POST_NOTIFICATIONS`（Android 13+）；未授权则运行时申请，拒绝仅提示，**不阻断**悬浮窗（前台服务通知不可见） |
| 开始收音 | 运行时申请 `RECORD_AUDIO`；授权后启动 `VoiceService`（`foregroundServiceType=microphone`） |
| `VoiceService` 启动失败 | 保留应用内收音；退到后台可能被系统暂停，悬浮窗仍显示最后一行 |
| 关闭悬浮窗 | 读取位置 → 持久化 → 关闭 `OverlayService`；同时停止 `VoiceService` |

清单与降级路径同步在 [permissions.md](../permissions.md)。部分厂商（MIUI/EMUI/ColorOS）可能还需要额外的「后台弹窗」开关，失败时按未授权路径提示。

## 3. 组件与跨引擎通信

```
ReaderPage（主 FlutterEngine）                          ReaderOverlayApp（悬浮窗 FlutterEngine）
  ├─ OverlayWindowService ── flutter_overlay_window ──► OverlayService（specialUse 前台服务）
  │                                                        └─ 独立 FlutterEngine + TYPE_APPLICATION_OVERLAY 窗口
  └─ OverlayBridge.incoming ◄── overlay_bridge（原生转发）──► OverlayBridge.incoming
```

- **为什么不用插件的 `shareData` / `IsolateNameServer`**：悬浮窗引擎由插件单独创建，与主引擎不在同一 isolate group，端口不可互通；且插件在悬浮窗引擎内也会注册自己的 messenger，`onMessage` 会回环到自身。
- **通道**：`BasicMessageChannel` + `JSONMessageCodec`，通道名 `com.tp.prompter.teleprompter/overlay_bridge`（稳定的 IPC 协议标识，不随应用包名变更）。`overlay_bridge` 插件的原生层分别保存主/浮窗两条引擎的通道（主引擎先创建，第二个接入者即浮窗引擎），任一侧 `send` 即转发到另一侧。
- **启动握手**：浮窗 `initState` 发 `ready`（每 500 ms 重试，最多 10 次）；主页面收到后回 `init`。
- **`init` 字段**：`title`、`lines`（段落文本，兼容旧浮窗）、`rows`（视觉行文本，新浮窗优先）、`anchor`（段落索引）、`anchorRow`（当前视觉行号）、`anchorOffset`（段内字符偏移）、`lineCount`、`fontSize`、`opacity`、`theme`、状态字段，以及 v2 可选几何字段 `layoutVersion`、`bandRatio`、`rowHeight`、`typographyModel`（旧浮窗忽略即可）。`bandRatio` 用于浮窗预览与按比例定位，不参与行号换算。
- **增量**：主页面每 200 ms 检查锚点，视觉行变化时发 `anchorRow`/`anchorOffset` 与 `anchor`；状态（开始/播放/锁定/收音）变化时发 `state`（按签名去重）。
- **样式**：`style` 携带 `widthDp`、`opacity`、`lineCount`、`fontSize`；浮窗收到后 `resizeOverlay(widthDp, heightDp, true)` 立即重排。
- **关闭**：`closeOverlay`/`getOverlayPosition` 只在主引擎注册，因此关闭按钮发 `close` 给主页面，由主页面读取位置、持久化并关闭服务。

## 4. 状态机（阅读页 ↔ 悬浮窗）

| 主页面状态 | 悬浮窗表现 | 主页面回写 |
|---|---|---|
| `started=false` | 播放键为「开始」图标；锁定不可用 | 浮窗点播放 → 主页面 `_start` |
| `started && !paused` | 暂停图标；锚点每 200 ms 推进 | — |
| `started && paused` | 播放图标；锚点不动 | 浮窗点暂停 → 主页面 `_togglePause` |
| `finished=true`（篇尾） | 播放图标；锚点停在末行 | 浮窗点播放 → 主页面 `_togglePause` → 循环复位回篇首并继续 |
| `locked=true` | 控制栏替换为「锁定」条，仅可解锁 | 浮窗点锁定条 → 主页面 `_unlock` |
| `voiceOn=true` | 头部显示收音角标，麦克风高亮 | 浮窗点麦克风 → 主页面 `_toggleMic`（含 `VoiceService` 启停） |
| 行宽变化重排版 | 重新接收 `init`，视觉行与段内偏移同步修正；语音跟随不断麦 | 主页面重建行映射并热替换对齐索引 |

> 2026-11-10 起正文只按空行分段，段内按宽度自然折行。新浮窗优先读 `rows`/`anchorRow`（视觉行），旧浮窗回退 `lines`/`anchor`（段落）；两种粒度都能显示，不会越界。

锁定状态下，浮窗的暂停/逐行/麦克风动作在主页面被忽略（防止误触）；解锁入口始终可用。

### 4.1 功能栏手动隐藏（2026-11-10）

- 阅读页底部功能栏新增「隐藏功能栏」按钮；点击后顶部栏与底部栏一起淡出，并全局持久化到 `app_settings.reader_panel_hidden`（跨台本、跨重启）。
- 隐藏时右侧保留一个可发现的把手（`ValueKey('reader-panel-handle')`，`chevron_left`，带 `readerShowPanel` 文案与 Tooltip），单击即唤出功能栏并清除持久化标记。
- 隐藏不影响语音跟随、录制与悬浮窗同步：这些链路只依赖锚点与定时器，不依赖面板可见性；锁定态下把手隐藏，但锁定角标仍可点击解锁，解锁后把手恢复。

## 5. 尺寸、坐标与持久化

`flutter_overlay_window` 的初始 `width/height/startPosition` 直接作为物理像素写入 `WindowManager.LayoutParams`，而 `resizeOverlay/moveOverlay/getOverlayPosition` 走 dp。为保持语义一致：

- 显示时把 `OverlaySettings` 的 dp 乘以 `MediaQuery.devicePixelRatio` 再传；
- `resizeOverlay` 直接传 dp；
- 位置读取结果是 dp，按 dp 持久化，下次显示再换算为 px；
- 窗口高度由可见行数推导：3 行 300 dp、5 行 420 dp（每行最多折两行，高度需容纳标题栏与 40 dp 控制栏）。旧配置中的全稿（`lineCount=0`）在读取时迁移为 5 行 / 420 dp。

`.resizeOverlay` 的重排锚点由插件与 WindowManager 的 gravity 决定（本机观察为保持底边、上沿随高度移动），因此位置以关闭时 `getOverlayPosition` 的实测结果为准。

持久化：
- 键：`overlay:global`（`presets` 表，与台本预设 `script:<id>` 分离）。
- 字段：`widthDp`（200–1200，设置面板 200–600）、`opacity`（0.3–1.0）、`lineCount`（3/5；读到 `0` 或越界值统一归一到 5）、`fontSize`（16–40）、`x`/`y`（dp）。
- 归一化在 `OverlaySettings.normalized()` 内收口，坏数据回退默认。

## 6. 已知限制与风险

1. 主 Activity 退后台后，主引擎的 Ticker 不再产生帧；锚点推进依赖主引擎的 ASR 回调与 200 ms 定时器，若系统限制后台定时器/音频回调，悬浮窗只保留最后一行。`VoiceService` 只保证麦克风前台服务凭据，不代跑 ASR。
2. 全稿模式已下线：旧配置的 `lineCount=0` 在 `OverlaySettings.normalized()` 中迁移为 5 行窗口，设置面板不再提供「全稿」选项；浮窗始终按窗口行数渲染并自动跟随锚点。
3. 浮窗字号与主阅读页字号独立（浮窗 16–40，默认 24），避免为了浮窗改动阅读排版。
4. 悬浮窗覆盖在阅读页时会遮挡设置面板，属系统悬浮窗层级；需要调整样式时可先拖开或暂时关闭。
5. 不同厂商 ROM 的悬浮窗与后台启动限制不同；拒绝/失败路径统一提示，不重试。

## 7. 验证入口

- 代码：`OverlayWindowService`（权限/显示/关闭/位置）、`ReaderOverlayApp`（窗口 UI）、`ReaderPage._toggleOverlay` / `_onOverlayMessage`（权限与同步）、`PlatformBridge` + `VoiceService`（通知与麦克风前台服务）。
- 单测：`test/overlay_settings_test.dart`（默认值、归一化、JSON 往返、高度映射）。
- 设备用例与结果：`docs/testing/records/20261106-m2.md` §14（逐条标注「实测通过 / 仅接入未验证」）。
