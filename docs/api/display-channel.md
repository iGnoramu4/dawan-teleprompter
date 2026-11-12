# 外接显示通道契约（`tps/display`）

> 状态：approved ｜ 责任人：FE ｜ 更新：2026-11-10 ｜ 适用：`0.22.0+2025`
> 目的：定义阅读页向 HDMI/DP 副屏输出纯稿件的原生通道（计划 E7-1）。

## 1. 传输

| 项 | 值 |
|---|---|
| 通道 | `MethodChannel('tps/display')`（`StandardMethodCodec`） |
| 原生实现 | `ExternalDisplayController`（Android `DisplayManager` + `Presentation`） |
| 平台 | 仅 Android；iOS/macOS 未实现时 `listDisplays` 返回空、其余方法静默失败 |

## 2. 方法

### 2.1 `listDisplays`

入参：无。返回 `List<Map>`：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | int | `Display.displayId`，不含默认屏（`DEFAULT_DISPLAY`） |
| `name` | string | 显示名称 |
| `width` / `height` | int | 首选模式的物理分辨率 |
| `presentation` | bool | 是否带 `FLAG_PRESENTATION`（可用 `Presentation` 输出） |

### 2.2 `present`

入参：

| 字段 | 类型 | 说明 |
|---|---|---|
| `displayId` | int | 目标副屏；必须是 `listDisplays` 返回的 id |
| `lines` | `List<String>` | 视觉行文本切片（按主屏可用宽度折行后的单行文本），原生只负责按窗口截取 |
| `anchor` | int | 当前视觉行号（0 基），对应主页面阅读带中的行 |
| `fontSize` | double | 字号（sp），跟随阅读页设置 |
| `mirrored` | bool | 水平镜像（整屏 `scaleX = -1`） |
| `bandRatio` | double | 可选：文本块中心占副屏高度比例（0–1），默认 `0.5`；原生夹取到 `0.2–0.8` |

返回 `true`。原生在副屏创建 `Presentation`：黑底、白字、当前行高亮（`#FFD24A`、加粗），固定显示 5 行（当前行居中）；`bandRatio` 通过 `column.translationY = (bandRatio - 0.5) × 容器高度` 调整文本块垂直位置。

### 2.3 `update`

入参同 `present`（不含 `displayId`）。仅在副屏已显示时有效，否则忽略。

### 2.4 `dismiss`

入参：无。关闭当前 `Presentation`。

### 2.5 事件 `displayRemoved`

副屏被拔出/断开时，原生通过同一通道反向调用，参数为 `displayId`（int）。Dart 端停止更新并把按钮恢复为未开启态。

## 3. 行为与边界

- 无副屏或调用失败时，阅读页提示「未检测到外接显示器」/「无法在外接显示器上显示」，应用内提词不受影响。
- 无线投屏（Cast）通常为系统镜像，不会出现在 `listDisplays`；本通道只做独立副屏输出。
- 阅读页每 300 ms 比较 `anchor/layoutVersion/fontSize/mirrored/readAheadRatio` 签名，有变化才 `update`，避免高频通道调用。
- 阅读页退出、停止外接显示或副屏拔出时都会 `dismiss`，不留悬浮窗口。
- 行号坐标系与屏幕渲染一致：`lines` 是主页面按实际宽度折行后的视觉行，原生不做二次排版；段落不再按标点切分（2026-11-10 起语义行 = 段落），同一段落会占多个视觉行。

## 4. 兼容性

- 新增方法属于扩展：旧实现忽略未知方法即可；方法名变更必须同步 Dart 与原生并在本文件与 `CHANGELOG` 记录。
- `bandRatio` 为可选参数：旧 Dart 调用不传时原生按 `0.5` 居中；旧原生实现忽略该参数也不影响显示。
- `lines`/`anchor` 的字段类型未变，但语义从「按句切分的语义行」升级为「视觉行」。新版 Dart 下发视觉行后，旧原生仍按「行文本 + 行号」渲染，无需改动；旧 Dart 下发语义行时，新版原生也照常渲染，不会越界。
