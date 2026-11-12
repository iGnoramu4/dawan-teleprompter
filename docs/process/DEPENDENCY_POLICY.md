# 依赖引入与许可证审核流程

> 状态：生效 ｜ 责任人：TL ｜ 复核：M2 结束
> 与计划文档 §15.4（Apache-2.0 开源治理）配套。

## 1. 许可证白名单

| 许可 | 允许 | 备注 |
|---|---|---|
| Apache-2.0 | 是 | 需保留 NOTICE；与项目一致 |
| MIT / ISC | 是 | 保留版权声明 |
| BSD-2-Clause / BSD-3-Clause | 是 | 保留版权与免责声明 |
| Zlib / Unlicense / CC0 | 是 | 保留声明（若要求） |
| LGPL-2.1/3.0（动态链接） | 有条件 | 不得静态链接；需法务确认；优先避免 |
| GPL-2.0/3.0、AGPL | **否** | 与项目分发模型冲突 |
| SSPL、BUSL、Commons Clause | **否** | 非 OSI 开源/限制商用 |
| CC BY-NC、自定义"非商用" | **否** | 不符合 OSI 开源定义 |
| 无许可证（All rights reserved） | **否** | 未授权即禁止使用 |

模型权重单独适用 `MODEL_LICENSE.md`，不与代码白名单混用。

## 2. 引入前评估（新增依赖必须回答）

1. **必要性**：现有依赖或系统能力能否满足？自研成本是否更低？
2. **维护状态**：最近 12 个月有发布/提交；issue 有响应；非个人弃坑项目；
3. **平台支持**：Android/Windows/macOS 三端可用；不支持需说明降级；
4. **许可**：在白名单内；含传递依赖一并检查；
5. **体积**：安装包增量（Android 单 ABI / 桌面）> 1 MB 需说明来源与许可，仅记录，不作引入门禁；
6. **安全**：无已知高危漏洞；无动态下载可执行代码；
7. **可替换性**：是否被封装在最小接口后，便于替换。

评估结论写入 PR 描述；超过 3 个新依赖或引入原生 SDK 时，追加一份 ADR。

## 3. 操作命令

```bash
# 添加（锁定版本）
flutter pub add <pkg>

# 依赖树与传递依赖
dart pub deps --json > build/deps.json

# 许可证扫描（自研脚本，白名单校验）
dart run tool/license_scan.dart --input build/deps.json --allow docs/process/licenses.allow.json

# 过期与漏洞
dart pub outdated
osv-scanner --lockfile pubspec.lock
```

CI 在每次 PR 运行 `license_scan` 与 `osv-scanner`；任一失败即阻断合并。

## 4. 记录与归档

- `NOTICE`：构建时自动生成，含依赖名、版本、许可、版权行；
- `docs/process/licenses.allow.json`：白名单与已批准例外（含批准人、日期、原因）；
- `assets/licenses/`：随包分发的许可全文（字体、模型、特殊依赖）；
- 例外批准：TL + 维护者双签，记录在 ADR 或 allow 文件。

## 5. 更新策略

- 每季度第一个月执行一次依赖升级窗口；
- 补丁/安全更新可随时走 `fix(deps)` PR，不受窗口限制；
- 大版本升级必须单独 PR，附回归测试与包体/性能对比（包体仅记录，不阻塞）；
- 锁文件必须提交；禁止 `any` 版本约束；
- 不引入会修改全局构建行为、或要求关闭分析器的依赖。

## 6. 模型权重与第三方素材

- 模型不入 Git；`models.lock.json` 记录来源、SHA256、许可标识；
- 字体、图标、插画同样需要许可记录，禁止来源不明的素材；
- 参照实现（小白提词器）为闭源项目：**只借鉴思路与参数，不复制代码、资源、模型**（见计划文档 §5.10）。

## 7. 第三方素材登记

| 素材 | 版本/来源 | 许可 | 随包路径 | SHA256 | 大小 | 引入日期 |
|---|---|---|---|---|---|---|
| Source Han Sans SC Heavy（Noto Sans SC Black，同源） | Google Fonts NotoSansSC v41 / Source Han Sans 2.005R | SIL OFL 1.1（全文 `apps/app/assets/licenses/NotoSansSC-OFL.txt`） | `apps/app/assets/fonts/NotoSansSC-Black.ttf` | `f6a468a9a7270bbf913530a726f6762ba641bbad28183804568be92a4b6736e2` | 10,521,684 B（约 10.03 MiB） | 2026-11-06 |

- 阅读页字体令牌见 `design_system` `TpTokens.readerFontFamily` / `readerFontWeight`；
- 不做子集裁剪（体积只记录，不设门禁）；启动开销实测记录见 `docs/testing/records/`。

## 8. 已批准依赖登记（W-02 / W-03 悬浮提词）

| 依赖 | 版本 | 形态 | 许可 | 引入日期 | 结论 |
|---|---|---|---|---|---|
| `flutter_overlay_window` | 1.0.2 | pub 包（含 Android 原生代码） | MIT | 2026-11-06 | 批准 |
| `overlay_bridge` | 0.1.0 | 本地路径包 `packages/overlay_bridge`，自研 | 项目自有（Apache-2.0） | 2026-11-06 | 批准 |

`flutter_overlay_window` 的评估回答（§2）：

1. **必要性**：系统级悬浮窗需要 `TYPE_APPLICATION_OVERLAY`、前台服务、跨应用窗口与位置控制；自研需同时维护 Kotlin 服务、双 FlutterEngine 与窗口生命周期，成本更高，且易在 Android 12+/14+ 的悬浮窗与 FGS 限制上出错。
2. **维护状态**：pub.dev 持续发布，Android 15 目标 SDK 下可用；本应用仅使用 `isPermissionGranted` / `requestPermission` / `showOverlay` / `resizeOverlay` / `closeOverlay` / `moveOverlayTo` 等少数接口。
3. **平台支持**：仅 Android；桌面端本轮不做悬浮窗（Windows/macOS 无系统级悬浮窗 API），不支持时降级为应用内提词。
4. **许可**：MIT，白名单内；传递依赖无 GPL/AGPL。
5. **体积**：仅引入 Kotlin 服务与少量 Java 代码，APK 增量 < 100 KB。
6. **安全**：无动态下载可执行代码；不申请额外网络权限。
7. **可替换性**：全部调用封装在 `OverlayWindowService` / `overlay_channel.dart` 两个文件后，替换实现不影响阅读页。

`overlay_bridge` 不引入第三方代码：两个 FlutterEngine 不在同一 isolate group，插件的 `shareData` 与 `IsolateNameServer` 不可用，故以原生 `BasicMessageChannel` 转发 JSON。

## 9. 已批准依赖登记（E6-2 扫码配对）

| 依赖 | 版本 | 形态 | 许可 | 引入日期 | 结论 |
|---|---|---|---|---|---|
| `mobile_scanner` | 7.5.0 | pub 包（Android/iOS/macOS 原生实现） | BSD-3-Clause | 2026-11-06 | 批准 |

`mobile_scanner` 的评估回答（§2）：

1. **必要性**：遥控端需要读取主控端二维码；自研相机预览 + 条码解码需同时处理 CameraX、MLKit/Zxing 与三端权限，成本远高于引入成熟库。粘贴配对串作为手动后备始终保留。
2. **维护状态**：pub.dev 活跃（7.x 持续发布），支持 Android 21+/iOS/macOS；本项目只用 `MobileScanner` 预览与 `onDetect` 回调，以及 `MobileScannerErrorCode` 判断权限拒绝。
3. **平台支持**：Android/iOS/macOS 可用；Windows 无实现，点击扫码时提示并降级为粘贴配对串。
4. **许可**：BSD-3-Clause，白名单内；Android 传递依赖 `com.google.mlkit:barcode-scanning`（Apache-2.0，随包，仅本机离线识别，不联网）。
5. **体积**：Android 打包 MLKit 条码模型，预计 APK 增量约 3–5 MB（bundled，离线可用）；仅记录，不作门禁；未在 CI 实测最终包体。
6. **安全**：相机帧仅在本机解码，不上传；无动态下载可执行代码；`mobile_scanner` 自身声明 `CAMERA` 权限（插件 manifest 合并），应用侧另显式声明 `uses-feature camera required=false`。
7. **可替换性**：扫码页通过 `ScannerBuilder` 注入点隔离（测试用 fake 构建器），未来换库只改 `scan_page.dart`。

## 10. 已批准依赖登记（M2 录制 / 复盘）

| 依赖 | 版本 | 形态 | 许可 | 引入日期 | 结论 |
|---|---|---|---|---|---|
| `just_audio` | 0.10.6 | pub 包（Android/iOS/macOS 原生播放） | MIT | 2026-11-06 | 批准 |
| `core_recording` | 0.1.0 | 本地路径包 `packages/core_recording`，自研 | 项目自有（Apache-2.0） | 2026-11-06 | 批准 |

`just_audio` 的评估回答（§2）：

1. **必要性**：复盘需要按位置播放、暂停、拖动与倍速；`record` 只负责采集，不含回放。自研需处理三端媒体会话与音频焦点，成本高且易在后台/锁屏场景出错。
2. **维护状态**：pub.dev 持续维护（0.10.x），本项目只用 `setFilePath` / `play` / `pause` / `seek` / `setSpeed` / `positionStream` / `playingStream`。
3. **平台支持**：Android/iOS/macOS/Web 官方支持；Windows 无官方实现，复盘入口在 Windows 上捕获异常并提示，录制与导出不受影响（降级路径见 `docs/permissions.md`）。
4. **许可**：MIT，白名单内；传递依赖 `audio_session`（MIT）、`just_audio_platform_interface`（MIT）、`rxdart`（Apache-2.0）均在白名单。
5. **体积**：仅封装系统播放器，未打包解码器；Android APK 增量预计 < 300 KB（仅记录，不作门禁）。
6. **安全**：无动态下载可执行代码；不联网；音频仅读取应用私有目录内的 WAV。
7. **可替换性**：`ReplayController` 依赖 `ReplayAudio` 抽象，测试与替换播放器只需实现该接口。

`core_recording` 为纯 Dart 自研包（无 Flutter/平台依赖）：时间轴模型、10 Hz 采样、线性插值、SRT 导出；由 `RecordingController` 与 `ReplayController` 组合使用。

## 11. 许可扫描（M3 门禁）

- 工具：`tool/license_scan.dart`，扫描仓库内全部 `pubspec.lock`，按 pub 缓存中的 `LICENSE*` / `COPYING*` 文本识别许可；
- 白名单：Apache-2.0、MIT、BSD-2/3-Clause、ISC、Zlib、Unlicense（ADR-0003）；
- 失败条件：GPL/LGPL/MPL/EPL、未知许可、缓存中缺少许可文件；
- 基线（2026-11-06）：9 个 lock、176 个第三方包，Apache-2.0 15、BSD-3-Clause 126、MIT 32、BSD-2-Clause 2，0 冲突；
- 忽略清单 `tool/license_scan_ignores.txt` 仅允许登记不会进入 Android/macOS/Windows 构建的 Linux 专用传递依赖；当前仅 `dbus`（由 `wakelock_plus` / `file_picker_linux` 引入，MPL-2.0，不随包分发），新增条目需在 PR 说明来源链；
- 该工具不覆盖模型权重、字体与商店素材：权重见 [MODEL_LICENSE.md](../../MODEL_LICENSE.md)，字体许可需在 `NOTICE` 逐项登记。




