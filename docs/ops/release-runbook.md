# 发布 runbook

> 状态：生效（v0.17.0 不签名、仅 GitHub Release）｜ 责任人：TL/FE ｜ 更新：2026-11-06
> 目的：把「从 main 到安装包」的步骤固定下来；凭据只从环境变量或本机安全存储读取，禁止写入仓库。

## 0. 前置条件（v0.17.0 暂定口径）

| 项 | 状态 | 说明 |
|---|---|---|
| 发布版本号 | 已定 | `0.17.0`（构建号 `+2020`） |
| 发布渠道 | 已定 | GitHub Release，仅上传 Android APK；不进应用商店 |
| 版权人/商标持有人 | 已定 | 吃不饱；联系邮箱见 `SECURITY.md` |
| Android 签名 | 本版本跳过正式签名 | 产物使用模板默认 **debug 签名**（不是正式发布签名）；发布说明必须标注，安装需允许未知来源 |
| Apple Developer 证书与公证 | 本版本不发布 | macOS 安装包不在 v0.17.0 范围 |
| Windows 代码签名证书 | 本版本不发布 | Windows 安装包不在 v0.17.0 范围 |
| 模型权重分发方式 | 已定 | A+B：随包分发 T0 + 保留本地导入；权重不入 Git，见 [MODEL_LICENSE.md](../../MODEL_LICENSE.md) |

> **停止条件**：需要 sudo、管理员密码、系统级授权弹窗，或需要私钥/证书口令时，先向项目负责人请示，不自行生成或导入。
> v0.17.0 **不需要** keystore/Apple/Windows 证书；若改为正式签名或商店发布，必须停下等待凭据。

## 1. 发布前（T-3 天）

```bash
cd teleprompter
# 1) 工作区干净、在 main 最新
git status
git log --oneline -5

# 2) 版本号与 CHANGELOG
#    apps/app/pubspec.yaml: version: x.y.z+build
#    CHANGELOG.md 的 Unreleased 已整理

# 3) 四检
dart format --output=none --set-exit-if-changed .
cd apps/app && dart analyze --fatal-infos --fatal-warnings . && cd ../..
for p in packages/*; do (cd "$p" && dart analyze --fatal-infos --fatal-warnings .) || exit 1; done
dart run tool/check_imports.dart
cd apps/app && flutter test --coverage && cd ../..
dart run tool/check_coverage.dart --min 70
dart run tool/license_scan.dart

# 4) 文档门禁
npx markdownlint-cli2 "docs/**/*.md"      # 如未安装，记录跳过原因
lychee docs/README.md docs/**/*.md          # 如未安装，记录跳过原因
```

- 按 [release-checklist.md](../releases/release-checklist.md) 逐项打勾；
- 记录包体大小（只记录，不设门禁，ADR-0004）。

## 2. Android（v0.17.0 实际流程）

```bash
cd teleprompter/apps/app
# 确认模型权重已注入（权重不入 Git）
ls assets/models/zipformer-zh-14M-int8

flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

| 检查 | 说明 |
|---|---|
| 包名 | `com.dawan.teleprompter`（`android/gradle.properties`）；与旧包不构成覆盖升级，发布说明必须写明全新安装、旧数据不迁移 |
| 签名 | `apksigner verify --print-certs` 确认是 **debug 证书**；发布说明标注「非正式签名」 |
| 模型 | 解包后飞行模式启动语音跟随，确认 T0 可用 |
| ABI | 单 APK 含 arm64/armv7；如需拆分再用 `--split-per-abi`，本版本不拆 |
| 清单 | `CAMERA`（非必需）、`RECORD_AUDIO`、前台服务、`INTERNET` 与 [permissions-statement.md](../legal/permissions-statement.md) 一致 |
| 包体 | 记录大小（含随包模型），只记录不设门禁 |
| 校验 | 生成 `SHA256SUMS` 并回填发布说明 |

### GitHub Release 上传（需要 `gh` 登录凭据）

```bash
shasum -a 256 teleprompter/apps/app/build/app/outputs/flutter-apk/app-release.apk
gh release create v0.17.0 \
  teleprompter/apps/app/build/app/outputs/flutter-apk/app-release.apk \
  --title "v0.17.0 内测" --notes-file docs/releases/0.17.0.md
```

> 前提：本地目录已初始化 git 并关联目标 GitHub 仓库；当前工作区尚未初始化，需先确认仓库地址。
> 停止条件：`gh` 未登录、需要账号授权，或需要创建公开仓库时停下，不自行使用任何令牌或推送。
> v0.17.0 不进应用商店；商店素材与审核项不在本版本范围。

## 3. macOS（后续版本，不在 v0.17.0）

```bash
cd teleprompter/apps/app
flutter build macos --release
# 签名与公证（凭据就绪后执行；当前跳过）
# codesign --deep --force --options runtime --sign "Developer ID Application: ..." <app>
# xcrun notarytool submit <dmg> --keychain-profile <profile> --wait
# xcrun stapler staple <dmg>
```

| 检查 | 说明 |
|---|---|
| 沙盒 entitlement | 麦克风、相机、网络 server/client 与 [permissions-statement.md](../legal/permissions-statement.md) 一致 |
| 公证 | `spctl -a -t open --context context:primary-signature -v <dmg>` 通过 |
| 安装 | 新用户首次启动、TCC 弹窗、卸载残留 |

## 4. Windows（后续版本，不在 v0.17.0）

```bash
cd teleprompter/apps/app
flutter build windows --release
# 打包 MSIX/Inno Setup（凭据就绪后签名；当前跳过）
```

| 检查 | 说明 |
|---|---|
| SmartScreen | 签名后验证无警告；未签名版本仅内测分发 |
| 麦克风 | 系统隐私开关关闭时有降级提示 |
| 防火墙 | 首次开启遥控出现放行弹窗，选择专用网络后局域网可用 |

## 5. 发布物与归档

- 产物命名：`teleprompter-<version>-<platform>.<ext>`；同时生成 `SHA256SUMS`；
- 归档：`docs/releases/<version>.md` 回填 SHA256、商店链接与发布日期；
- 保留构建日志与符号文件（崩溃排查用），不上传到公开仓库。

## 6. 发布后

| 时间 | 动作 |
|---|---|
| +1 小时 | 冒烟：安装、启动、导入台本、阅读、录制 1 分钟、导出 |
| +1 天 | 监控商店崩溃/评分；收集诊断包 |
| +7 天 | 回归已知问题清单；必要时发补丁版本 |

## 7. 回滚

- 商店：下架/暂停分阶段发布，保留旧版本安装包；
- 桌面：撤回下载链接并发布公告；
- 代码：`git revert` 发布提交或从 release 分支打 hotfix；数据库 schema 只新增，不降级；
- 数据：录音与台本在应用私有目录，卸载即丢失；回滚说明中提醒用户先导出。
