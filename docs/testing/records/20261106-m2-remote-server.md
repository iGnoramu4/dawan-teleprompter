# M2 测试记录：遥控协议与服务端（E6-1）

> 阶段：M2 ｜ 构建：`0.13.0+2016` ｜ 日期：2026-11-06
> 目的：验证局域网遥控协议编解码、鉴权/封禁、命令去重与状态下行；本轮尚未接入遥控页 UI 与阅读页命令。

## 1. 环境

| 项 | 值 |
|---|---|
| 主机 | macOS（arm64），Flutter `3.47.9` stable |
| 测试方式 | `flutter test`（宿主回环 `127.0.0.1`，端口 0 随机分配） |
| 设备 | 本轮不涉及真机/模拟器 |

## 2. 用例

| 用例 ID | 场景 | 结果 | 备注 |
|---|---|---|---|
| RP-01 | 配对串 `tps://pair?...` 生成/解析往返 | 实测通过 | 协议/端口/token 一致 |
| RP-02 | 非法配对串（协议、主机、端口、缺 token） | 实测通过 | 返回 `null` |
| RP-03 | 128-bit token 长度与随机性 | 实测通过 | 32 位十六进制，两次不同 |
| RP-04 | hello 合法/补全 client | 实测通过 | 缺 client 记为 `unknown` |
| RP-05 | 消息版本、角色、token、类型校验 | 实测通过 | 非法均抛 `RemoteProtocolException` |
| RP-06 | cmd 各动作与可选字段 | 实测通过 | `speed`/`scroll` 需 delta，`jump` 需 sectionId，`mirror`/`lock` 需 value |
| RP-07 | 状态/命令下行字段 | 实测通过 | 行号坐标系字段齐全，可选字段按需输出 |
| RS-01 | hello 通过后立即收 `state`，命令回 `ack` | 实测通过 | 回环 WebSocket |
| RS-02 | 错误 token 关闭码 `4003` | 实测通过 | 关闭原因可读 |
| RS-03 | 连续 3 次错误 token 封禁 60 s，过期恢复 | 实测通过 | 注入时钟，封禁期正确 token 也收 `4004` |
| RS-04 | 重复 `seq` 只 ack 不重复执行 | 实测通过 | 命中去重分支 |
| RS-05 | 非法命令回 `error` 且连接保持可用 | 实测通过 | 后续命令仍可 ack |
| RS-06 | 已鉴权后再次 hello 回 `error` | 实测通过 | — |
| RS-07 | 状态仅在变化时按间隔下行 | 实测通过 | 同状态不刷屏 |
| RS-08 | `stop()` 关闭客户端并停止监听 | 实测通过 | 关闭码 `1000`，端口拒绝连接 |
| RS-09 | 非 `/ws` 路径返回 404 | 实测通过 | — |
| RS-10 | hello 超时关闭码 `4001` | 实测通过 | 短超时注入 |
| RS-11 | 首条消息非 hello 关闭码 `4002` | 实测通过 | — |

## 3. 覆盖率

- 新增 `remote_protocol.dart`、`remote_server.dart` 由上述用例覆盖。
- 全量：`flutter test --coverage` **111 项全部通过**；`dart run tool/check_coverage.dart --min 70` → **86.3%（1874/2171 行）OK**。

## 4. 未自动化 / 未验证

| 项 | 原因 | 替代验证 |
|---|---|---|
| 真实同一 Wi-Fi 跨设备连接 | 宿主测试只走回环，无法验证 AP 隔离、路由器防火墙、省电策略 | 局域网互传已用 `adb forward` 验证同类 `HttpServer` 监听；遥控页接入后在模拟器/真机同网段实测 |
| 端到端延迟 < 100 ms（P95） | 需要遥控页 UI 与两台设备 | 遥控页接入后同网段压测 |
| 手机遥控端 UI、断线重连 | 下一阶段（E6-2/E6-3） | — |
| Android 后台/锁屏对 WebSocket 的影响 | 需要设备前台服务与系统行为 | 真机回归 |

## 5. 提交前检查

| 检查 | 结果 |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | 通过（0 变更） |
| `dart analyze --fatal-infos --fatal-warnings`（app） | 通过，无问题 |
| `dart run tool/check_imports.dart` | 通过（`features/remote` 无跨 feature 依赖） |
| `flutter test --coverage` | 111 项全部通过 |
| `dart run tool/check_coverage.dart --min 70` | 通过：86.3%（1874/2171） |

## 6. 结论

- 实测通过（宿主回环）：协议编解码、鉴权与封禁、hello 超时、命令串行/去重、错误回执、状态节流、停服清理。
- 仅接入未验证：跨设备局域网、时延指标、遥控页 UI 与断线重连（下一阶段）。
- 本轮不改变既有业务行为；未新增依赖。
