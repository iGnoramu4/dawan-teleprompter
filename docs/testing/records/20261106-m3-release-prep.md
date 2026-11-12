# M3 测试记录：发布准备（无凭据部分）

> 阶段：M3 ｜ 构建：`0.17.0+2020` ｜ 日期：2026-11-06 ｜ 状态：进行中
> 目的：验证治理文件、发布/支持文档与许可扫描工具可用；签名、商店与版本决策不在本轮验证范围。
> 关联：[release-checklist.md](../../releases/release-checklist.md)、[release-runbook.md](../../ops/release-runbook.md)。

## 1. 本轮完成项

| 用例 ID | 内容 | 结果 | 证据 |
|---|---|---|---|
| M3-PREP-01 | `LICENSE` 为 Apache-2.0 全文，版权人已回填 | 实测通过 | 文件末尾 appendix：Copyright 2026 吃不饱 |
| M3-PREP-02 | `CONTRIBUTING` 含四检命令、DCO、PR/文档要求 | 实测通过 | 文件内容 |
| M3-PREP-03 | `CODE_OF_CONDUCT`、`SECURITY`、`TRADEMARK`、`MODEL_LICENSE` | 实测通过 | 联系人/持有人/版权均已回填 |
| M3-PREP-04 | `docs/releases/` 索引、0.17.0 说明、发布检查清单 | 实测通过 | 已按 v0.17.0 / GitHub Release / 非正式签名口径更新 |
| M3-PREP-05 | 发布 runbook 覆盖 Android APK 构建、GitHub Release、回滚 | 实测通过 | macOS/Windows 标注不在本版本 |
| M3-PREP-06 | 用户手册与 FAQ 覆盖导入/阅读/跟随/遥控/扫码/外接屏/录制 | 实测通过 | 步骤与降级说明一致 |
| M3-PREP-07 | 隐私政策与用户版权限说明 | 实测通过 | 与 `NOTICE`/`permissions.md` 一致 |
| M3-PREP-08 | `tool/license_scan.dart` 可运行并正确失败 | 实测通过 | 基线 0 冲突；MPL 包 `dbus` 经登记后跳过 |
| M3-PREP-09 | 文档索引已加入新文档 | 实测通过 | `docs/README.md` |
| M3-PREP-10 | 扫码配对状态复核 | 实测通过 | 见第 3 节 |
| M3-PREP-11 | Android release APK 构建（debug 签名） | 实测通过 | `teleprompter-0.17.0.apk` 210,175,561 bytes；SHA256 `211ec0db…69e09` |
| M3-PREP-12 | APK 内模型与 ABI 核对 | 实测通过 | `assets/flutter_assets/assets/models/zipformer-zh-14M-int8/` 4 文件齐全；含 arm64/v7a/x86_64 |
| M3-PREP-13 | APK 签名核对 | 实测通过 | `apksigner`：`CN=Android Debug`，非正式签名 |

## 2. 许可扫描基线

```text
license_scan: 9 个 lock 文件，176 个第三方包
  跳过 1 个仅 Linux 依赖（见 tool/license_scan_ignores.txt）
  Apache-2.0: 15
  BSD-2-Clause: 2
  BSD-3-Clause: 126
  MIT: 31
  MIT / Apache-2.0: 1
license_scan: OK
```

- 忽略项仅 `dbus`（MPL-2.0，由 Linux 平台实现传递引入，不进入 Android/macOS/Windows 构建）；
- 工具对 GPL/LGPL/MPL/未知/缺失许可返回退出码 1（本轮未构造失败用例，逻辑为静态检查）；
- 不覆盖模型权重、字体与商店素材。

## 3. 扫码配对复核

| 项 | 结论 |
|---|---|
| 代码 | `lib/features/remote/scan_page.dart` + `remote_page.dart` 扫码入口，`mobile_scanner ^7.5.0` 已解析 |
| 降级 | 权限拒绝、通用错误、Windows 均展示说明并保留「粘贴配对串」 |
| 宿主测试 | `flutter test test/scan_page_test.dart test/remote_page_test.dart`：12 项通过 |
| Android 编译 | 上轮 `:app:compileDebugKotlin` 通过（MLKit 依赖解析）；本轮未重跑 |
| 真机相机/授权弹窗 | **仅接入未验证** |

## 4. 四检

- `dart format --set-exit-if-changed .`：113 文件，0 变更；
- `dart analyze --fatal-infos --fatal-warnings`（apps/app）：无问题；`tool/license_scan.dart` 单独分析无问题；
- `check_imports`：OK；
- `flutter test --coverage`：163 项通过；覆盖率 81.6%（2704/3315）≥ 70%。

## 5. 未完成 / 待用户决策（已回填 2026-11-06）

| 项 | 状态 |
|---|---|
| 版权人、商标持有人、联系邮箱 | 已回填：吃不饱 / 见 `SECURITY.md` |
| 发布版本与渠道 | 已定：`0.17.0`，GitHub Release 仅 APK，不进商店 |
| 签名 | 本版本跳过正式签名；APK 为 Flutter 模板默认 debug 签名 |
| 模型权重分发 | 已定 A+B；`tool/models.lock.json` 登记 SHA256；权重不入 Git |
| 模型上游许可 | **待 ALG 核对上游模型卡**，是发布门禁（不是凭据问题） |
| 本地导入入口 | 规则已定，v0.17.0 未实现；发布说明不得宣称支持 |
| 真机安装、相机/麦克风授权、30 分钟长录 | 需真机；本轮未验证 |
| 商店素材、备案/软著 | v0.17.0 不需要 |

## 6. 后续（下一步）

- [x] 构建 Android release APK（debug 签名），记录包体与 SHA256，回填发布说明；
- [x] 生成 `SHA256SUMS`（`apps/app/build/app/outputs/flutter-apk/SHA256SUMS`）；
- [ ] GitHub Release 上传：`gh` 已登录（iGnoramu4），但当前目录**不是 git 仓库、无 remote**；需确认目标仓库并初始化/关联后才能上传。**停下请示**，不自行创建公开仓库或推送。
- [ ] 真机安装、相机/麦克风授权、30 分钟长录：需要设备，停下等待人工操作；
- [ ] 模型上游模型卡核对：ALG 提供 URL/许可，是发布门禁；
- [ ] 模型本地导入入口：v0.17.0 未实现，后续迭代。

构建命令：`flutter build apk --release`（92.8 s，Gradle `assembleRelease`）。

