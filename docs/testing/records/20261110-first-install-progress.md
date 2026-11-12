# 首读进度提示：解包进度 / 阶段区分 / 失败重试

日期：2026-11-10
范围：仅首次语音跟随的模型准备链路（`ModelInstaller` → `VoiceFollowSession` → 阅读页提示），不改识别参数与对齐逻辑。

## 1. 问题与改动

首次点「开始跟读」时，209 MB 中英混合模型要解包到应用私有目录，旧实现只有「安装离线模型…」「加载识别器…」两句静态文案，无法判断是否卡死。

- 解包进度来自 `ModelInstaller` 的真实写盘量：4 MB 分块写入后上报 `ModelInstallProgress(bytesDone/bytesTotal/currentFile)`，百分比按字节计算，无定时器动画。
- 已安装（marker 命中）时 `ensure` 直接返回，不触发 `onStart`/`onProgress`，二次启动不会闪解包进度。
- 两阶段分开：安装阶段显示 `安装离线模型… {percent}%（{done} / {total} MB）`，安装完成后切换为 `加载识别器…（通常几秒）`。
- 失败态：`ensure` 统一抛 `ModelInstallException{file, cause, cleaned}`；失败时递归删除半成品目录，`cleaned` 如实记录是否删干净。阅读页 SnackBar + `重试` 按钮，`cleaned` 决定文案是「已清理」还是「未能清理，请检查存储空间」。
- 文案全部走 ARB（`voiceInstallModelProgress`、`voiceLoadingRecognizer`、`readerModelInstallFailed`、`readerModelInstallFailedUnclean`、`actionRetry`），中英各一份。

### 改动文件

| 文件 | 内容 |
| --- | --- |
| `teleprompter/packages/asr_kit/lib/src/model_installer.dart` | `fileBytes`/`totalBytes`、`ModelInstallProgress`、`ModelInstallException`、`freshlyInstalled`、`onStart`/`onProgress` 注入、4 MB 分块真实进度、失败清理半成品 |
| `teleprompter/apps/app/lib/features/reader/voice_follow.dart` | `installModel` 注入、安装/加载两阶段状态、`asr/installed` 事件 |
| `teleprompter/apps/app/lib/features/reader/reader_page.dart` | `_showError(onRetry:)`、`ModelInstallException` 分支、麦克风/回放失败的重试入口 |
| `teleprompter/apps/app/lib/l10n/app_zh.arb`、`app_en.arb` | 新增 5 条文案 |
| `teleprompter/apps/app/test/model_installer_test.dart` | 新增 5 项 |
| `teleprompter/apps/app/test/voice_follow_test.dart` | 新增 3 项（阶段顺序、已安装路径、失败传播） |
| `teleprompter/apps/app/test/reader_page_interaction_test.dart` | 失败态改断言新文案与「重试」入口 |

## 2. 自动化验证（实测通过）

- `dart analyze lib test`：`No issues found!`
- `flutter test --coverage`（arm64 SDK）：**195 项全部通过**（上轮 187 + 新增 8）。
- 覆盖率：`tool/check_coverage.dart` 统计 **81.2%（3179/3915 行）**，阈值 ≥70%。

覆盖点：

1. 进度单调递增、4 MB 分块（5 MB 文件产生 ≥2 次回调）、末次 `percent == 100`、`bytesDone == totalBytes`；
2. 已安装二次调用：`onStart`/`onProgress` 均为 0 次、不重复读 assets、`freshlyInstalled == false`；
3. 第 3 个文件读/写失败：抛 `ModelInstallException(file=joiner.onnx, cleaned=true)`，目录被整体删除；同一路径再次调用可成功；
4. 目录创建失败（用同名文件占位，模拟写盘路径不可用）：`cleaned=true`、`cause` 为 `FileSystemException`；
5. `VoiceFollowSession` 状态序列：`安装 → 38%/3 MB/8 MB → 加载识别器`，安装失败时不会进入加载阶段；已安装时首个状态就是 `加载识别器`；
6. 阅读页：失败后回滚到未开麦、SnackBar 含「离线模型安装失败」与 `重试`。

## 3. 设备实测（0.23.0 release，小米 24091RPADC / SM8635 / Android 16）

条件：`pm clear` 清数据 + 预授予麦克风/通知权限（避免权限弹窗遮住界面）、`screenrecord` 90 fps 录屏，5 fps 抽帧读状态栏。设备：`f37aa514`。

| 时间点（录屏内） | 状态栏 |
| --- | --- |
| 1.6 s | `安装离线模型…` |
| 2.0 s | `安装离线模型… 38%（76 / 198 MB）` |
| 2.4 s | `安装离线模型… 84%（168 / 198 MB）` |
| 2.6 s | `加载识别器…（通常几秒）` |
| 7.0 s | `请求麦克风…` |
| 8.0 s | `跟读中（麦克风）` |

点按发生在录屏约 1.0–1.3 s，因此：

- 解包（0→100%）约 **1.0–1.6 s**（本次 APK 刚安装、页缓存偏热，属偏快口径）；
- 识别器加载约 **4.4 s**（2.6 → 7.0 s）；
- 麦克风 + 前台服务约 **1.0 s**；
- 点按到「跟读中」合计约 **6.7–7.0 s**，与既有 10.7 s 记录同一量级。

需要修正上一轮口径：**10.7 s 是「首次准备」端到端耗时，不是纯解包耗时**；本次纯解包约 1.5 s，加载识别器约 4.4 s（与「约 4 秒」预期一致），二者已分开显示。

截图：

- [01 解包 38%](images/20261110-first-install-progress/01-install-38pct.png)
- [02 解包 84%](images/20261110-first-install-progress/02-install-84pct.png)
- [03 加载识别器（独立阶段）](images/20261110-first-install-progress/03-loading-recognizer.png)
- [04 二次启动：直接加载，无解包进度](images/20261110-first-install-progress/04-second-start-no-install.png)
- [05 解包失败 + 重试](images/20261110-first-install-progress/05-install-failed-retry.png)

### 二次启动

停止跟读后再次点麦克风，录屏 1.2 s 起即为 `加载识别器…（通常几秒）`，全程无「安装离线模型」/百分比（截图 04）。

### 失败回滚与重试（实测）

release 包不可 `run-as`，失败注入用 **debug 构建**（同签名）完成，行为与 release 代码一致：

1. 安装 debug 包并清数据，`run-as` 在应用支持目录放一个同名普通文件 `files/asr_models`，使 `Directory.create` 必然失败；
2. 点麦克风 → 状态栏与 SnackBar 显示「离线模型安装失败，点「重试」重新安装；未完成的模型文件已清理」，SnackBar 带 `重试`；`run-as ls files` 确认不存在 `files/asr_models/<id>` 目录（无半成品）；
3. 删除占位文件后点 `重试` → 正常解包 → `加载识别器…`；
4. `run-as` 核对落盘结果：四个文件与 marker 齐全，字节数与 `fileBytes` 完全一致：
   - `encoder-epoch-99-avg-1.int8.onnx` 181,895,032
   - `decoder-epoch-99-avg-1.onnx` 13,876,452
   - `joiner-epoch-99-avg-1.onnx` 12,833,618
   - `tokens.txt` 56,317
   - `.installed-v1`（marker）

设备后续已恢复安装 release 包（清数据 + 预授权限）。

## 4. 实测通过与未验证项

- 实测通过：首次解包百分比推进（38% → 84%）、解包与加载阶段切换、二次启动不出现解包进度、注入失败后的失败态/重试/半成品清理、重试成功后的文件完整性。
- 仅接入未验证：`cleaned=false`（删除半成品失败）分支在设备上的真实文案——需要文件被占用或权限异常才能触发，本次仅由代码路径与单测覆盖，未在真机构造。
- 未验证：低存储（磁盘剩余 < 210 MB）场景的失败文案与清理结果；建议后续用 `adb shell` 填盘或小分区设备补测。

## 5. 包与签名（本轮重打）

- 文件：`apps/app/build/app/outputs/flutter-apk/teleprompter-0.23.0.apk`
- 大小：396,751,372 B（上一版 0.23.0 为 396,734,988 B，+16,384 B）
- SHA256：`5465e8c9f5d1d0958cd0c14c3f001cf2df1777e173cd17ccb3b885f9ade8a925`（`SHA256SUMS` 已更新）
- 签名：`CN=Android Debug`（v2），versionCode 2026，versionName 0.23.0
- 设备已安装该包（`adb install -r` 成功）。
