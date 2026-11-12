# 0.23.0 应用层测试补跑与工具链修复（2026-11-10）

> 背景：0.23.0 出包前，`apps/app` 的 `flutter test` 在本机被原生资源 hook 阻断，未取得应用层结果与覆盖率。
> 本文记录工具链根因、修复方式、补跑结果、覆盖率与仍未验证项。
> 环境：macOS（arm64）+ Flutter 3.47.9 / Dart 3.13.7。

---

## 1. 工具链问题与修复

### 1.1 现象

`apps/app` 执行 `flutter test` 时，构建阶段失败于原生资源 hook：

- `objective_c`：`xcrun: unable to load libxcrun ... need 'x86_64'`
- `pdfium_dart`：`XCodeSdkResolver` 报 `SDK macosx not installed` / `Bad state: No element`

### 1.2 根因

本机同时存在两套 Flutter SDK，且只有 CommandLineTools（无完整 Xcode）：

| 路径 | Dart 架构 | 结果 |
|---|---|---|
| `$HOME/flutter-sdk/flutter` | `Mach-O x86_64` | 失败（经 Rosetta 运行） |
| `$HOME/flutter-sdk/arm64/flutter` | `Mach-O arm64` | 通过 |

x86_64 的 Flutter/Dart 进程 fork 出的 `xcrun` 子进程同样是 x86_64，而本机 `/Library/Developer/CommandLineTools` 的 `libxcrun` 仅提供 arm64 切片，因此 `dlopen` 失败；两个包的原生资源 hook 都要调用 `xcrun` 解析 SDK，于是同一处被卡住。**不是缺完整 Xcode**：arm64 SDK + 现有 CLT 即可完成资源构建。

### 1.3 修复

不安装 Xcode、不改系统配置，改用 arm64 SDK 执行：

```bash
cd teleprompter/apps/app
$HOME/flutter-sdk/arm64/flutter/bin/flutter test --coverage
```

同一工程、同一 Dart 版本（3.13.7），只更换 SDK 架构，`pubspec.yaml`/`pubspec.lock` 无需改动。

---

## 2. 补跑结果

| 项 | 结果 |
|---|---|
| 全量用例 | **187 项通过，0 失败**（补跑前基线 182 项，本次新增 5 项） |
| 退出码 | 0 |
| 覆盖率（`apps/app` 整体） | **81.1%（3157/3893 行）**，阈值 ≥70% 通过 |
| 静态分析 | `dart analyze lib test` → No issues found |

新增用例（5 项）：

| 文件 | 用例 | 覆盖点 |
|---|---|---|
| `test/reader_settings_test.dart` | 识别模型默认中英混合，14M 可切回且往返不丢 | 默认值、`copyWith`、`toJson`/`fromJson` 往返 |
| `test/reader_settings_test.dart` | 旧预设缺识别模型键按中英混合加载，不改写用户数据 | 缺键回落、其它字段保留、读取不就地改写入参 |
| `test/reader_settings_test.dart` | 识别模型选择映射到随包模型规格 | `AsrModelChoice.spec` → `AsrModelSpec` id/assetDir |
| `test/reader_settings_sheet_test.dart` | 识别模型默认中英混合，可切回中文轻量 | 设置页区块、默认选中、切换回传、说明文案切换 |
| `test/voice_follow_test.dart` | 启动路径默认用中英混合模型，切中文轻量按传入规格生效 | `VoiceFollowSession` 默认/显式 `modelSpec` |

改动文件行覆盖：`reader_settings.dart` 133/133（100%）、`reader_settings_sheet.dart` 285/289（98.6%）。

---

## 3. 本轮改动面回归

| # | 改动面 | 结论 | 证据 |
|---|---|---|---|
| 1 | 默认模型 `zipformerBilingualMixed` | 通过 | `ReaderSettings.defaults.asrModel`、`VoiceFollowSession` 默认 `modelSpec` 均为混合模型 |
| 2 | 识别模型可切回中文轻量 | 通过 | 设置面板切「中文轻量」回传 `AsrModelChoice.zh14m`，JSON 往返与模型映射同时校验 |
| 3 | 旧预设缺键按混合加载、不改写用户数据 | 通过 | 缺键 json 解析后为混合模型，`fontSize`/`theme`/`lineStepFollow` 保持，入参 map 未被补键 |
| 4 | 语音跟随启动路径 | 部分通过 | 会话构造的模型规格已覆盖；`_prepare()` 之后的解包与 sherpa 引擎加载依赖真机/原生库，单测不可达 |
| 5 | 设置页文案 | 通过 | 「中英混合 / 中文轻量」标签、两段模型说明与「切换后于下次开始语音跟随时生效」均断言 |

未发现产品缺陷；本轮未改产品行为（`VoiceFollowSession.modelSpec` 为只读 getter，仅暴露构造时已保存的规格）。

---

## 4. 仍未验证

1. **真机首启解包**：`ModelInstaller.ensure` 对 209 MB 资产的首次落盘耗时、进度提示与失败回滚，只能在真机复测。
2. **sherpa 引擎按所选模型加载**：单测只验证规格传递，`_prepare()` 之后的 native 加载与识别输出未在测试中执行（`voice_follow.dart` 行覆盖 41.6%，其余为原生依赖分支）。
3. **旧预设真实数据迁移**：只覆盖 JSON 层；线上用户数据库中的既有预设未做采样验证。
4. **真实环境音 30 分钟补测**：仍待用户执行，不用现有静音/合成数据替代结论。

---

## 5. 复现

```bash
cd teleprompter/apps/app
$HOME/flutter-sdk/arm64/flutter/bin/flutter test --coverage

cd ..  # teleprompter
$HOME/flutter-sdk/arm64/flutter/bin/dart run tool/check_coverage.dart \
  --lcov apps/app/coverage/lcov.info
# → [app] 81.1% (3157/3893 行, 要求 >= 70%) OK
```

---

## 6. 0.23.0 重出包记录（2026-11-10，与当前源码严格一致）

构建命令：`$HOME/flutter-sdk/arm64/flutter/bin/flutter build apk --release`（`apps/app`）。

| 项 | 值 |
|---|---|
| 文件 | `apps/app/build/app/outputs/flutter-apk/teleprompter-0.23.0.apk`（同目录 `app-release.apk`） |
| 大小 | **396,734,988 B**（约 378.4 MiB），与上一版 0.23.0 包**字节数完全相同，增量为 0** |
| SHA-256 | `0b4180ce9aecccfdd17bce87573faad0ebe2e2b19225adbe78bdd6cab53b65b5` |
| versionName / versionCode | `0.23.0` / `2026`（minSdk 24，targetSdk 36） |
| 签名 | Android Debug 证书（`CN=Android Debug`，证书 SHA-256 `249f4471fc32f4568e2fe0227df4992e38383c9e88ccd2f84e64678659546183`），仅 **APK Signature Scheme v2** 通过（v1/v3/v4 为 false） |
| 上一版对照 | `teleprompter-0.23.0-r1.apk`，396,734,988 B，SHA-256 `341b124c5438eb5528e19e6df15e25e879eec17a5ba9d4c4c56d9fb29a840853` |
| 是否安装 | **未安装**，装机由用户决定 |

体积未变但内容确实重新编译，依据：两包 `lib/*/libapp.so` 的 SHA-256 全部不同（如 arm64 `abebc63a…` vs `c2e979f2…`），`libflutter.so` 相同；三 ABI 的 `libapp.so` 长度一致（对齐取整）导致包体字节数相同。

`SHA256SUMS` 已更新为两份 0.23.0 记录（新包 + r1 旧包），`shasum -a 256 -c` 全部 OK。

