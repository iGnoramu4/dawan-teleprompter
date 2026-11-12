# overlay_bridge

自研 Flutter 插件（仅 Android），在主 FlutterEngine 与
`flutter_overlay_window` 创建的悬浮窗 FlutterEngine 之间双向转发 JSON 消息。

`flutter_overlay_window` 的 `shareData` 依赖 `IsolateNameServer`，
而悬浮窗引擎与主引擎不在同一 isolate group，端口无法互通；
且插件自带的 messenger 在悬浮窗引擎内会回环。因此这里用原生
`BasicMessageChannel` 直接连接两条引擎的 `BinaryMessenger`。

## 用法

两端都用同一个通道名发送即可，原生层会把消息转给另一条引擎。
通道名是稳定的 IPC 协议标识，与应用包名（`com.dawan.teleprompter`）无关，改名不会改变它：

```dart
const channel = BasicMessageChannel<dynamic>(
  'com.tp.prompter.teleprompter/overlay_bridge',
  JSONMessageCodec(),
);
```

## 注册顺序

主引擎先创建，悬浮窗引擎其次；插件据此判定谁是主引擎。
新增引擎（例如第二个悬浮窗）不在当前支持范围内。
