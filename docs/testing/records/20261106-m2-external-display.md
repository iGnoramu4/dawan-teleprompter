# M2 测试记录：外接显示（E7-1）

> 阶段：M2 ｜ 构建：`0.15.0+2018` ｜ 日期：2026-11-06
> 目的：验证 `tps/display` 通道的 Dart 服务契约、阅读页开关与滚动同步；真实 HDMI/DP 副屏与时延不在本轮验证范围。
> 契约见 [display-channel.md](../../api/display-channel.md)。

## 1. 环境

| 项 | 值 |
|---|---|
| 主机 | macOS（arm64），Flutter `3.47.9` stable |
| Dart 测试 | `flutter test`：`TestDefaultBinaryMessenger` 假通道 |
| 原生编译 | `./gradlew :app:compileDebugKotlin` 通过（未打包，未安装到设备） |
| 设备 | 无副屏设备/模拟器 |

## 2. 用例

### 2.1 Dart 服务（`test/external_display_test.dart`）

| 用例 ID | 场景 | 结果 | 备注 |
|---|---|---|---|
| ED-01 | `ExternalDisplay.tryParse` 解析合法副屏 | 实测通过 | 分辨率/名称/presentation |
| ED-02 | 缺 `id`、非 Map 返回 null；字段缺失取默认 | 实测通过 | `name=Display <id>`、宽高 0 |
| ED-03 | `listDisplays` 解析并丢弃非法条目 | 实测通过 | 2 条输入 → 1 条 |
| ED-04 | 原生报错或未实现时返回空列表 | 实测通过 | 不影响应用内提词 |
| ED-05 | `present` 透传 displayId/lines/anchor/fontSize/mirrored | 实测通过 | 参数完整 |
| ED-06 | `present` 失败返回 false；`update`/`dismiss` 静默吞异常 | 实测通过 | 副屏拔出后不抛 |
| ED-07 | `displayRemoved` 事件经流下发 | 实测通过 | 参数 displayId |
| ED-08 | `dispose` 后不再派发事件 | 实测通过 | 解除通道 handler |

### 2.2 阅读页接入（`test/reader_page_interaction_test.dart`）

| 用例 ID | 场景 | 结果 | 备注 |
|---|---|---|---|
| ED-09 | 无副屏时提示「未检测到外接显示器」且不调用 `present` | 实测通过 | 按钮保持不变 |
| ED-10 | 单副屏直接输出，显示当前行/全文/字号 | 实测通过 | `present` 参数含 3 行文本 |
| ED-11 | 下一行后 300 ms 内下发 `update`，锚点为 1 | 实测通过 | 节流签名 |
| ED-12 | 再点按钮 `dismiss` 并恢复空心图标 | 实测通过 | 停止外接显示 |
| ED-13 | 多副屏弹出选择列表，选中后使用对应 displayId | 实测通过 | SimpleDialog |

## 3. 覆盖率

- 全量：`flutter test --coverage` **133 项全部通过**；`dart run tool/check_coverage.dart --min 70` → **86.2%（2321/2693 行）OK**。
- `external_display.dart` 由 ED-01~08 覆盖；阅读页开关/同步由 ED-09~13 覆盖。

## 4. 未自动化 / 未验证

| 项 | 原因 | 替代验证 |
|---|---|---|
| 真实 HDMI/DP 副屏显示效果 | 本轮无外接设备，模拟器默认无副屏 | 真机 + HDMI 采集卡/外接屏回归 |
| `Presentation` 生命周期与旋转/热插拔 | 需要真实 `DisplayManager` 事件 | 真机拔插、旋转、休眠唤醒回归 |
| 原生渲染字体/高亮与拍摄距离 | 只有真机才能评估可读性 | 现场录制确认 |
| 端到端刷新延迟 | 300 ms 轮询 + 原生渲染，未测量 | 真机高速滚动录屏比对 |
| 无线投屏（Cast）场景 | 系统镜像不会产生 Presentation 显示 | 保持应用内提词 + 提示文案 |
| iOS/macOS 副屏 | 原生未实现 | 后续按需补 `UIScene`/`NSWindow` |

## 5. 提交前检查

| 检查 | 结果 |
|---|---|
| `dart format --output=none --set-exit-if-changed .` | 通过（0 变更） |
| `dart analyze --fatal-infos --fatal-warnings`（app） | 通过，无问题 |
| `dart run tool/check_imports.dart` | 通过 |
| `./gradlew :app:compileDebugKotlin` | 通过（仅有既有依赖的 deprecation 提示） |
| `flutter test --coverage` | 133 项全部通过 |
| `dart run tool/check_coverage.dart --min 70` | 通过：86.2%（2321/2693） |

## 6. 结论

- 实测通过（宿主）：通道参数、错误降级、拔出事件、阅读页开关/滚动同步/多屏选择。
- 实测通过（编译）：Kotlin 原生代码可编译。
- 仅接入未验证：真机 HDMI/DP 输出与可读性、热插拔、时延、Cast、iOS/macOS。
- 未新增第三方依赖；通道名与方法遵循 `docs/architecture/ARCHITECTURE.md` §8 契约。
