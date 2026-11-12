# 构建与运行

本文覆盖 Android / macOS / Windows 三端的本地构建、运行与常见问题。发布流程、签名与归档规则另见 [发布手册](docs/ops/release-runbook.md)。

## 1. 环境

| 工具 | 版本 / 说明 |
|---|---|
| Flutter | 3.47.9（stable），见 `.fvmrc` |
| Dart | 随 Flutter 提供（3.13.x） |
| Android | JDK 17、Android SDK（compileSdk 使用 Flutter 默认值）、一台 Android 8+ 设备或模拟器 |
| macOS | macOS 12+、Xcode 16+、CocoaPods |
| Windows | Windows 10/11、Visual Studio 2022（Desktop development with C++） |
| Python | 3.10+（仅重新生成图标时需要，依赖 Pillow 与 NumPy） |

> **含空格路径**：本工程可在含空格的路径下构建，但 `flutter analyze` 在部分 Flutter 版本下会崩溃，静态检查请使用 `dart analyze`。

## 2. 拉取依赖

```bash
cd teleprompter
flutter pub get

cd apps/app
flutter pub get
```

工程使用 melos 组织多包，但日常开发只需在 `apps/app` 与改动的 `packages/*` 下执行 `flutter pub get` / `dart pub get`。

## 3. 语音模型权重

权重不进入 Git。构建前按 `teleprompter/tool/models.lock.json` 准备以下目录：

```
teleprompter/apps/app/assets/models/zipformer-zh-14M-int8/
teleprompter/apps/app/assets/models/zipformer-bilingual-mixed/
```

要求：

1. 文件名、体积必须与 `models.lock.json` 的 `files` 一致；
2. 下载后逐个校验 SHA256：

   ```bash
   shasum -a 256 teleprompter/apps/app/assets/models/*/*.onnx
   ```

3. 权重来源与再分发边界见 [MODEL_LICENSE.md](MODEL_LICENSE.md)；上游模型卡：
   - 中文轻量：<https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23>
   - 中英混合：<https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20>
4. 中英混合模型按清单使用 int8 encoder + fp32 decoder/joiner，随包目录中去掉 `.int8` 后缀，不要自行替换为全 int8 版本。

目录内保留 `README.md` 占位，保证未放置权重时 Flutter 仍能解析 assets 目录并完成构建；此时语音跟随不可用。

## 4. 运行

```bash
cd teleprompter/apps/app
flutter devices
flutter run -d <device-id>
```

- Android：首次启动会请求麦克风、通知、悬浮窗权限；语音跟随按需解包模型。
- macOS：首次运行需在「系统设置 → 隐私与安全性 → 麦克风」授权。
- Windows：麦克风权限由系统设置控制。

## 5. 构建

### Android

```bash
cd teleprompter/apps/app
flutter build apk --release
# 或
flutter build appbundle --release
```

- 包名统一由 `android/gradle.properties` 的 `appApplicationId` 控制（当前 `com.dawan.teleprompter`），`namespace` 与 `applicationId` 共用该值。
- 签名配置放在 `android/key.properties`（已被 `.gitignore` 排除），字段：`storeFile`、`storePassword`、`keyAlias`、`keyPassword`。不要把签名文件或口令提交到仓库。
- 发布包必须在**格式化已收敛**的源码上构建：先跑 `dart format --output=none --set-exit-if-changed .` 确认 0 变更，再构建；构建完成后不得再改手写源码。若构建后改了源码，必须重打、重算 SHA256，并更新 `dist/SHA256SUMS` 与发布说明。

### macOS

```bash
cd teleprompter/apps/app
flutter build macos --release
```

- Bundle Identifier：`com.dawan.teleprompter`（`macos/Runner/Configs/AppInfo.xcconfig`）。
- 对外分发需在 Xcode 中配置开发者证书并完成公证；本地构建会使用自动签名。

### Windows

```bash
cd teleprompter/apps/app
flutter build windows --release
```

- 产物位于 `build/windows/x64/runner/Release/`。
- Windows 桌面应用没有 bundle identifier；可执行文件名保持 `teleprompter.exe`，显示名与文件属性中的产品名为「大皖提词器」。
- 安装器（如 Inno Setup / MSIX）不属于本仓库构建链路，需另行配置。

## 6. 图标

图标母版、Android 自适应图标、Android 12+ 启动画面、Windows `.ico`、macOS `.iconset/.icns` 均由同一脚本生成：

```bash
cd teleprompter
python3 tool/generate_icons.py
```

产物：

- `assets/branding/icon_master_1024.png`
- `assets/branding/android/mipmap-*`
- `assets/branding/windows/app_icon.ico`
- `assets/branding/macos/AppIcon.iconset`、`AppIcon.icns`
- `docs/assets/branding/icon-preview.png`

脚本会同步写入 `apps/app/android/.../res`、`apps/app/windows/runner/resources` 与 `apps/app/macos/Runner/Assets.xcassets`。修改几何参数后重新运行即可，不要手改各密度 PNG。

## 7. 检查与测试

```bash
cd teleprompter

dart format --output=none --set-exit-if-changed .

cd apps/app && dart analyze --fatal-infos --fatal-warnings . && cd ../..
for p in packages/*; do (cd "$p" && dart analyze --fatal-infos --fatal-warnings .) || exit 1; done

dart run tool/check_imports.dart
cd apps/app && flutter test --coverage && cd ../..
dart run tool/check_coverage.dart --min 70
dart run tool/license_scan.dart
```

覆盖率门槛为 70%，不得通过排除文件的方式规避。

## 8. 常见问题

| 现象 | 处理 |
|---|---|
| `flutter analyze` 在中文/空格路径下崩溃 | 改用 `dart analyze`；或在 `apps/app`、`packages/*` 内分工作区执行 |
| Flutter 版本与宿主架构不匹配导致构建失败 | 使用与宿主架构一致的 Flutter SDK（Apple Silicon 用 arm64 版本） |
| Android 构建报缺少 `local.properties` | 由 Flutter/Gradle 自动生成，不要提交 |
| 启动后语音跟随提示模型缺失 | 按第 3 节放置权重并校验 SHA256 |
| 修改包名后旧安装无法覆盖 | 包名变更即全新应用；旧数据不迁移，需卸载旧包后安装新包 |
