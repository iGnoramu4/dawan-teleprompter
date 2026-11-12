# 原生代码规范（Android / Windows / macOS）

> 状态：生效 ｜ 责任人：FE（平台方向） ｜ 复核：M1 结束
> 原则：**原生只做平台能力，不做业务逻辑**；业务规则全部在 Dart。

## 1. 边界与通信契约

- 原生层只暴露"能力接口"：悬浮窗、全局热键、外接显示、权限状态、音频会话、前台服务。
- Dart 侧统一经 `tp_platform` 调用；业务层禁止直接 `MethodChannel`。
- 通道命名：`tps/<module>`（如 `tps/overlay`、`tps/hotkey`、`tps/display`）。
- 方法名：`lowerCamelCase`，动词开头：`showOverlay`、`hideOverlay`、`registerHotkey`。
- 参数/返回值统一 `Map<String, Object?>`，字段在 [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) 的"通道契约"登记。
- 错误统一返回 `FlutterError(code, message, details)`，错误码固定枚举：

| code | 含义 |
|---|---|
| `E_PERMISSION` | 权限未授予（附 `permission` 字段） |
| `E_UNAVAILABLE` | 当前平台/设备不支持 |
| `E_STATE` | 调用时序错误（未初始化/已释放） |
| `E_SYSTEM` | 系统 API 失败（附原始 code，不附用户数据） |

- 通道契约变更属于**破坏性变更**：必须升版本字段 `v`，Dart/原生同 PR 修改，并在 ADR 或接口文档记录。

## 2. Android（Kotlin）

- 语言：Kotlin，禁止 Java 新代码；协程 `Dispatchers.Default` 做 IO/编解码，主线程只更新视图。
- 包结构：`com.<org>.prompter.<module>`，插件实现放 `tp_platform_android`。
- 组件：
  - 悬浮窗用 `TYPE_APPLICATION_OVERLAY`，必须处理 `SYSTEM_ALERT_WINDOW` 未授权；
  - 长时任务用前台服务，`foregroundServiceType="microphone"`（仅跟随/录制时）；
  - 外接显示用 `Presentation` + `DisplayManager`，监听热插拔并回退主屏。
- 生命周期：`onDestroy` 必须注销监听、释放 WindowManager、停止服务；不得持有 Activity 引用。
- 权限：不在原生层静默申请；由 Dart 经 `permission_handler` 触发，原生只查询状态。
- 清单：每个 `uses-permission` 必须有 `docs/permissions.md` 对应条目（计划文档 §10.11），CI 比对。
- 资源：字符串走 `res/values/strings.xml` 并同步 ARB；不在 Kotlin 里写用户可见文案。
- 测试：纯逻辑用 JUnit；涉及系统 API 的用 `androidTest` + 至少 2 台真机。

## 3. Windows（C++ / Win32）

- 仅通过 federated plugin 的 C++ 实现（Flutter Windows embedding）。
- 窗口样式：`WS_EX_TOPMOST | WS_EX_LAYERED | WS_EX_TOOLWINDOW`；点击穿透用 `WS_EX_TRANSPARENT`，切换时必须 `SetWindowLongPtr` + `SetWindowPos(...SWP_FRAMECHANGED)`。
- 线程：Win32 调用只在平台线程；耗时操作（缩略图、文件解析）回 Dart Isolate，不阻塞消息循环。
- 错误处理：HRESULT 必须检查并映射到 `E_SYSTEM`；不吞错误。
- 资源释放：`DestroyWindow`、`UnregisterHotKey`、`ReleaseDC` 必须在插件销毁时执行。
- 热键：`RegisterHotKey` 冲突时返回 `E_STATE`（附冲突键），Dart 提示改键。
- 字符串：用户可见文案不写死在 C++；日志用英文、结构化。

## 4. macOS（Swift / Objective-C++）

- 优先 Swift；仅在需要 C++ 互操作时用 ObjC++，并在文件头注释原因。
- 悬浮面板：`NSPanel` + `.nonactivatingPanel`，`collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`；不得抢占焦点。
- 权限：
  - 麦克风：`AVCaptureDevice.requestAccess`，Info.plist `NSMicrophoneUsageDescription`；
  - 辅助功能（全局热键）：`AXIsProcessTrustedWithOptions`，未授权降级；
  - 本地网络：沙盒 `com.apple.security.network.server/client`。
- 生命周期：`deinit`/`applicationWillTerminate` 移除事件监听、释放面板、停止音频。
- 沙盒：所有文件访问走用户选择（`NSOpenPanel`）或应用容器；不越权读外部路径。
- 签名：Hardened Runtime + 公证；禁止关闭 SIP 相关私有 API。
- 测试：XCTest 覆盖能力层；UI 行为用真机清单（全屏 App、多 Space、多显示器）。

## 5. 原生代码评审附加项

- [ ] 通道方法有版本与错误码，Dart 侧已同步
- [ ] 无业务逻辑、无硬编码文案
- [ ] 所有监听/句柄/窗口在销毁时释放
- [ ] 权限拒绝路径已实现并返回 `E_PERMISSION`
- [ ] 无阻塞平台线程的同步 IO
- [ ] 真机验证记录附在 PR（设备型号 + 系统版本 + 场景）
