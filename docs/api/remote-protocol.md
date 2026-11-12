# 局域网遥控协议（v3）

> 状态：approved ｜ 责任人：FE ｜ 更新：2026-11-10 ｜ 适用：`0.22.0+2025`
> 目的：定义主控端（阅读页）与手机遥控端之间的 WebSocket 契约（计划 §10.5、R-03/R-04）。
> 版本策略：v3 把语义行从「按句切分」改为「段落」，并新增**可选**的段内字符与视觉行字段；主控端继续接受 v1/v2 上行消息，旧遥控端可忽略新字段。

## 1. 传输与配对

- 服务端由用户显式开启，仅监听 IPv4；默认端口 `7788`，路径 `/ws`。
- 传输为 WebSocket + JSON 文本帧，当前协议版本字段 `v` 为 `3`；主控端兼容接受 `v` 为 `1`、`2` 的上行消息。
- 配对串格式：`tps://pair?host=<ip>&port=<port>&token=<32 位十六进制>&v=3`，二维码承载；`v` 仅作展示，解析时不强校验。
- token 为 128-bit 随机值，首次配对写入；关闭服务即失效。
- 心跳使用 WebSocket 协议层 ping，间隔 `2 s`。

## 2. 消息

### 2.1 上行（遥控端 → 主控端）

```json
{"v":3,"type":"hello","role":"remote","token":"...","client":"android"}
{"v":3,"type":"cmd","seq":12,"action":"play"}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `type` | string | `hello` 或 `cmd`；鉴权后只接受 `cmd` |
| `seq` | int | 非负，同一连接内单调递增；重复只回 ack，不重复执行 |
| `action` | string | `play` / `pause` / `next_line` / `prev_line` / `speed` / `scroll` / `jump` / `mirror` / `lock` |
| `delta` | number | `speed`（行/秒增量）与 `scroll`（行数增量）必填 |
| `value` | bool | `mirror` / `lock` 必填 |
| `sectionId` | string | `jump` 必填 |

### 2.2 下行（主控端 → 遥控端）

```json
{"v":3,"type":"state","anchorLine":7,"anchorOffset":42,"anchorRow":19,"rowProgress":0.5,"layoutVersion":7,"conf":0.82,"speed":1.0,"playing":true,"scriptTitle":"...","progress":0.31,"mirrored":false,"locked":false,"lineCount":18,"lineUnit":"paragraph","anchorText":"当前段落文本","anchorRowText":"当前视觉行文本","rowHeight":62.5,"rowCount":96,"bandRatio":0.34,"typographyModel":2}
{"v":3,"type":"ack","seq":13}
{"v":3,"type":"error","message":"未知动作"}
```

| 字段 | 类型 | 说明 |
|---|---|---|
| `anchorLine` | int | 当前语义行号（0 基），必填；v3 起语义行 = 段落，缺失或非整数时遥控端丢弃该帧 |
| `anchorOffset` | int | v3 可选：锚点在 `anchorLine` 内的字符偏移（按归一化前原文字符计），默认 `0` |
| `anchorRow` | int | v3 可选：锚点所在视觉行号（按可用宽度折行后），默认 `0` |
| `rowProgress` | number | v3 可选：按视觉行计算的进度，0–1；缺省时遥控端回退到 `progress` |
| `lineUnit` | string | v3 可选：`anchorLine` 的单位，`sentence`（v2 及更早）或 `paragraph`（v3），默认 `sentence` |
| `layoutVersion` | int | 行布局版本，行宽/字号变化后递增 |
| `conf` | number | 语音跟随置信度，0–1 |
| `speed` | number | 当前速度（行/秒） |
| `playing` | bool | 是否正在滚动 |
| `scriptTitle` | string | 台本标题 |
| `progress` | number | 按语义行计算的阅读进度，0–1；定义与 v2 相同 |
| `mirrored` / `locked` | bool | 镜像/锁定状态 |
| `lineCount` | int | 语义行总数，`0` 表示未知 |
| `anchorText` | string | 当前语义行文本，主控端截断到 60 字符（含省略号） |
| `anchorRowText` | string | v3 可选：当前视觉行文本，优先用于展示；默认空串 |
| `rowHeight` | number | v2 可选：视觉行高（逻辑像素），`0` 表示未知；旧遥控端忽略 |
| `rowCount` | int | v2 可选：视觉行总数，`0` 表示未知；旧遥控端忽略 |
| `bandRatio` | number | v2 可选：阅读带中心占屏高比例（0–1），默认 `0.5`；旧遥控端忽略 |
| `typographyModel` | int | v2 可选：排版模型，`1` 旧 / `2` 紧凑；默认 `1`；旧遥控端忽略 |

- `state` 采用行号坐标系：行号由渲染端统一分配，遥控端不做像素换算；`layoutVersion` 变化时遥控端应丢弃本地文本切片缓存。
- **v3 语义变更**：`anchorLine` 的单位由「按句切分的语义行」变为「段落」（`lineUnit=paragraph`）。这会让同一台本在 v2/v3 下的 `anchorLine` 数值不同；为避免静默改变语义：
  - 新遥控端必须读取 `lineUnit`；`paragraph` 时以 `anchorRow`/`rowProgress` 展示进度，`anchorLine` 仅作为段落定位。
  - v2 遥控端会忽略新字段，继续把 `anchorLine` 当句行使用；由于段数 ≤ 句行数，表现为「进度粒度变粗、但不会越界」，属于可接受的降级，主控端不为此回退语义。
  - `jump` 动作仍以 `sectionId` 定位，不受 `anchorLine` 单位变化影响。
- `state` 以 `200 ms` 为最小间隔，仅在快照变化时下发；鉴权成功时立即下发一次。
- 篇尾暂停时 `playing=false`、`progress=1.0`；循环复位后恢复 `playing=true` 且 `anchorLine` 回到 `0`。
- `error` 不关闭连接，供遥控端提示；协议错误由关闭码表达（见 §3）。

### 2.3 遥控端行为（E6-2）

- 入口：设置页「遥控端」；粘贴主控端展示的配对串后连接（当前版本未实现扫码，扫码需引入 `mobile_scanner`，见测试记录）。
- 建连超时 `5 s`；连接成功即以 `seq` 从 `1` 单调递增发送 `cmd`，并记录最近 `ack` 序号。
- 意外断开：提示「连接已断开」，`1 s` 后自动重连，最多 `3` 次；超过后进入失败态，展示「重新连接」按钮。
- 用户主动断开/离开页面：停止重连并关闭底层连接。
- 锁定态下遥控端禁用上一行/下一行/播放暂停/调速，仅保留镜像与解锁；最终以主控端 `state.locked` 为准。

### 2.4 主控端命令语义（E6-3）

| 动作 | 主控端行为 | 锁定态 |
|---|---|---|
| `play` / `pause` | 开始/暂停滚动（等价于用户点击屏幕） | 忽略 |
| `next_line` / `prev_line` | 锚点 ±1 段（段落化后语义行 = 段落），段内偏移归 0 | 忽略 |
| `speed` | `delta` 叠加到速度，范围 `0.2–10.0` 行/秒 | 忽略 |
| `scroll` | `delta` 行滚动手势（保留给连续拖动） | 忽略 |
| `jump` | 按 `sectionId` 跳到分段首行 | 忽略 |
| `mirror` | 切换水平镜像并持久化到台本预设 | 允许 |
| `lock` | 进入/退出锁定态（锁定后屏幕手势失效） | 允许（用于解锁） |

- 主控端每次视觉行布局重建（字号/行宽变化）递增 `layoutVersion`，并立即尝试下行新状态；语义行（段落）集合不随宽度变化。
- 阅读页关闭遥控弹窗不停止服务；点「停止遥控」或离开阅读页才停止监听。

## 3. 关闭码

| 关闭码 | 含义 |
|---|---|
| `4001` | 未在 `5 s` 内完成 hello 鉴权 |
| `4002` | 首条消息不是合法 hello |
| `4003` | token 不匹配 |
| `4004` | 来源地址处于封禁期 |
| `1000` | 服务端主动停止 |

连续 3 次 token 错误后封禁来源地址 `60 s`；封禁期内即使 token 正确也拒绝。

## 4. 安全与约束

- 仅局域网使用、默认关闭、不开放公网端口；不提供文件系统访问。
- 不启用 TLS：token 用于防误连，不防同网段嗅探，隐私说明须如实告知。
- 同一连接上的命令串行处理；`seq` 去重，避免多遥控并发重复触发。
- 目标延迟：同网段端到端 < 100 ms（P95）；断线立即提示，`1 s` 后自动重连，最多 `3` 次（客户端职责）。

## 5. 版本兼容与迁移路径

| 版本 | 状态字段变化 | `anchorLine` 语义 | 兼容性 |
|---|---|---|---|
| v1 | `anchorLine`、`layoutVersion`、`conf`、`speed`、`playing`… | 按句切分的语义行 | 仍接受上行；旧客户端可继续工作 |
| v2 | 新增可选 `rowHeight`/`rowCount`/`bandRatio`/`typographyModel` | 同上 | 旧客户端忽略新字段 |
| v3 | 新增可选 `anchorOffset`/`anchorRow`/`rowProgress`/`lineUnit`/`anchorRowText` | **段落**（`lineUnit=paragraph`） | 旧客户端忽略新字段，按段落粒度展示 |

- 不做静默语义回退：主控端不会为了兼容 v2 而把 `anchorLine` 降级成句行；旧客户端看到的是「同一字段、更粗的粒度」。
- 新客户端必须按 `lineUnit` 解释 `anchorLine`；`sentence` 时可继续按句行处理，`paragraph` 时建议优先使用 `anchorRow` 与 `rowProgress`。
- `jump` 以 `sectionId` 定位，不依赖 `anchorLine` 单位，因此跨版本行为一致。
- 回滚路径：若需回到 v2，删除新增字段并将 `v` 写回 `2`；主控端对缺失新字段按 §2.2 的默认值处理，不会因字段缺失拒绝状态。
