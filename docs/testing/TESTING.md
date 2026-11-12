# 测试规范

> 状态：生效 ｜ 责任人：QA ｜ 复核：M1 结束（补评测集实测数据）
> 阈值与计划文档 §3.3、§14 保持一致；冲突时以计划文档为准。

## 1. 测试分层与边界

| 层 | 范围 | 工具 | 运行时机 | 要求 |
|---|---|---|---|---|
| 单元测试 | `packages/core_*`、归一化、拼音、DP、滚动、数据模型 | `dart test` / `flutter test` | 每次提交 | 核心包覆盖率见 §3 |
| 组件测试 | Widget 行为、语义、主题、空态/错误态 | `flutter test` | 每次 PR | 关键页面必须有 |
| Golden | 视觉基线（浅/深、compact/expanded、镜像） | `flutter test --update-goldens` | 每次 PR | 变更需人工确认 diff |
| 集成测试 | 真机全链路（导入→编辑→跟随→暂停→退出） | `flutter test integration_test -d <id>` | 每日/发布前 | 三端各至少 1 台 |
| 评测集 | ASR + 对齐 + 滚动指标 | `tool/eval` | 算法变更必跑、发布前必跑 | 见 §5 |
| 性能/长跑 | CPU、内存、帧率、耗电、稳定性 | DevTools / 平台工具 | 里程碑门禁 | 见 §6 |
| 手工验收 | 权限、悬浮窗、外接屏、遥控、无障碍 | 清单 | 发布前 | 见 §7 |

**不写测试的情形**：纯 UI 布局微调（用 golden 覆盖）、生成代码、常量表。生成代码与手工维护的常量表（如混淆表）需有数据来源校验测试。

## 2. 命令

```bash
# 单元 + 组件
flutter test --coverage

# 仅核心包（快速）
dart test packages/core_alignment packages/core_scroll

# Golden
flutter test --update-goldens test/golden

# 集成（示例）
flutter test integration_test/app_test.dart -d <device-id>

# 评测集（工具在 teleprompter/tool/eval，评测集在 teleprompter/eval）
cd tool/eval && flutter pub get
dart run run_eval.dart \
  --model-dir ../../apps/app/assets/models/zipformer-zh-14M-int8 \
  --out ../../build/eval-report.json
# 真机：见 eval/README.md §5.3（tool/eval_device harness）
```

> 本机注意：`apps/app` 必须用 arm64 Flutter SDK 执行（`$HOME/flutter-sdk/arm64/flutter/bin/flutter`）。
> x86_64 SDK 经 Rosetta 调起的 `xcrun` 无法加载 arm64-only CommandLineTools 的 `libxcrun`，会让
> `objective_c` / `pdfium_dart` 的原生资源 hook 失败；详见 `records/20261110-app-test-toolchain.md`。

## 3. 覆盖率要求

| 范围 | 行覆盖 | 分支覆盖 |
|---|---|---|
| `packages/core_alignment` | ≥ 85% | ≥ 75% |
| `packages/core_scroll` | ≥ 85% | ≥ 75% |
| `packages/core_models` / `data_store` / `import_kit` | ≥ 75% | — |
| `apps/app`（整体） | ≥ 60% | — |
| 本次 PR 新增/修改代码 | ≥ 80% | — |

统计：

```bash
flutter test --coverage
dart run tool/check_coverage.dart --min 70 --core-min 85
```

未达标的 PR 不得合入，除非在 PR 中说明原因并获得 TL 批准（记录在 PR）。

## 4. 测试数据与隐私

- 评测音频必须是**自录或授权素材**，附书面授权记录；禁止使用真实用户音频；
- 测试台本使用虚构内容，不含个人信息；
- 测试产物（录音、日志）不入 Git，放 `build/` 或 CI 临时目录；
- Golden 图片中不得出现真实姓名、账号、设备标识。

## 5. ASR 与跟随评测方法（沿用计划文档口径）

### 5.1 评测集构成（60 段）

| 类别 | 段数 | 要求 |
|---|---|---|
| 普通话男声 | 12 | 不同年龄/语速 |
| 普通话女声 | 12 | 不同年龄/语速 |
| 方言口音 | 10 | 至少 3 种口音 |
| 中英混读 | 8 | 术语、缩写、品牌名 |
| 含口误/重复/甩词 | 8 | 用于回跳抑制 |
| 含跳读/插话 | 6 | 用于追赶收敛 |
| 噪声/回声 | 4 | 舞台音箱、人群噪声 |

每段 60–120 s，人工标注"每句话对应的脚本 token 区间"。标注文件与音频同目录，格式见 `eval/labels/*.json`。

### 5.2 指标定义

| 指标 | 定义 | 目标 |
|---|---|---|
| 首字跟随延迟 | 说话起始 → 首次滚动的时间差 | ≤ 500 ms（P95 ≤ 800 ms） |
| 稳态跟随误差 | 锚点行与人工标注行的绝对差 | ≤ 0.5 行（P95 ≤ 1 行） |
| 跳读收敛 | 跳读后回到正确位置所需句数 | ≤ 2 句 |
| 静音误滚动 | 30 min 无语音时的滚动次数 | < 1 次 |
| 口误回跳 | 30 min 内因重复/甩词回跳次数 | 0 次 |
| 连续稳定 | 60 min 无崩溃、无累计漂移 | 通过 |

### 5.3 回归规则

- 算法改动必须跑全量评测集，输出 `build/eval-report.json`；
- 任一关键指标相对基线退化 > 5% 或绝对值越界 → 阻塞合并；
- 基线数据存 `eval/baseline.json`，每次发布更新并记录版本；
- 调参记录写入 PR（参数、数据、结论），不靠口头传递。

### 5.4 对齐引擎专项

- 归一化：标点、全半角、数字读法、繁简、英文大小写；
- 拼音：多音字、混淆表（55 条）命中与不命中用例；
- DP：单调约束、带宽、回跳抑制、置信度边界；
- 性质测试：随机插入/删除/替换字符，结果不得产生非法锚点（负值、越界、回退）。

## 6. 性能与内存基线

**基准机型**：Android 中高端档——骁龙 8 Elite（Snapdragon 8 Elite）级 SoC + 12 GB RAM，Android 15/16，高刷屏（120 Hz）。所有帧率/CPU/内存/耗电基线以该档实测为准；低端机（4 GB RAM、入门 SoC）**只作冒烟记录，不保证体验，不作为门禁或设计约束**。

| 指标 | 基线（基准机型） | 测量方法 |
|---|---|---|
| 冷启动到首页 | < 1.5 s | `flutter run --profile` + 时间戳日志 |
| 跟随态帧率 | ≥ 55 fps（目标 120 Hz 屏上无持续掉帧） | DevTools Frame chart / `--trace-skia` |
| 跟随态 CPU | 单核 < 25% | `adb shell top -H` / Windows 任务管理器 / Activity Monitor |
| 内存（含模型） | < 400 MB | `adb shell dumpsys meminfo` / Instruments |
| 1 小时耗电 | < 8% | 电池测试脚本，亮度/音量固定 |
| 模型加载 | < 1 s（常驻） | 启动日志 |
| 包体 | **仅记录，不设上限、不作为门禁** | 构建产物 |

> **决策（2026-11-06，用户要求）**：取消「Android 单 ABI ≤ 120 MB」等体积基线门禁，也不为压体积做拆 ABI、裁资源之类的取舍。优先级为**稳定、易用、开发方便**；包体超标只在测试记录中如实记录（含构建号、ABI/通用包、模型与字体资产占比），不阻塞合并与发布。计划文档 §3.3/§14.4 中的体积目标与语句视为被本决策取代（计划文档本轮不改动，以本节为准）。

> **决策（2026-11-06，用户要求）**：性能定位调整为**中高端基准**（骁龙 8 Elite / 12 GB 档）；不为低端机做性能妥协，低端可用性不再作为门禁或设计约束。已核查现有实现无低端专属降级：未限制字形/图片缓存、未锁帧率、未简化滚动与高亮特效、未对 ASR 模型额外降采样或降精度（现用 `zipformer-zh-14M-int8` 为精度/速度常规选择，保持）。阅读页 `FrameTiming` 采样缓冲上限 3600 帧仅为诊断内存边界，与机型无关，保留。详见 ADR-0005。

测量要求：

- 使用 profile/release 构建，禁止 debug 数据作为结论；
- 每项测 3 次取中位数；记录设备型号、系统版本、构建号；
- 结果写入 `docs/testing/records/<YYYYMMDD>-perf.md`（模板见 TEMPLATES.md）。

## 7. 真机矩阵

| 平台 | 基准（门禁机型） | 兼容（冒烟记录） | 必测场景 |
|---|---|---|---|
| Android | 骁龙 8 Elite / 12 GB、Android 15/16、arm64 | Android 10+、4–8 GB、入门/中端 SoC（**体验未保证，不门禁**） | 跟随/跟随态高刷滚动、悬浮窗、后台 30 min、权限拒绝 |
| Windows | Win11 x64、16 GB | Win10 x64、4–8 GB | 多显示器、置顶、全局热键、麦克风权限 |
| macOS | macOS 14+、Apple Silicon | macOS 13、Intel | 全屏 App 覆盖、多 Space、TCC 权限、公证包 |

补充：至少 1 台蓝牙脚踏板/遥控器、1 台 16:9 外接显示器、1 套分光镜（或等效镜像验证）。低端 Android 仅在兼容机列表做启动/导入/阅读冒烟，结果写记录，不作为发布阻塞项。

## 8. 发布门禁（与计划文档 §14.4 对应）

- [ ] 单测/组件/golden 全绿，覆盖率达标
- [ ] 评测集全指标达标，无回归
- [ ] 三端集成测试通过
- [ ] 性能/内存/耗电基线在**基准机型**（骁龙 8 Elite / 12 GB 档）达标；低端机结果仅记录，不阻塞
- [ ] 权限拒绝路径逐项手工验证
- [ ] 无障碍：TalkBack/Narrator 主流程可完成
- [ ] 网络开关关闭时抓包零外连
- [ ] 许可扫描与 NOTICE/MODEL_LICENSE 完整
- [ ] release 无敏感日志
- [ ] 30/60 分钟长跑通过
- [ ] 包体只记录（构建号 + 大小 + 资产占比），不设阈值、不阻塞发布

## 9. 缺陷分级

| 级别 | 定义 | 处理 |
|---|---|---|
| P0 | 崩溃、数据丢失、隐私泄露、无法启动 | 立即修，阻塞发布 |
| P1 | 主流程不可用、跟随严重漂移 | 当前里程碑修 |
| P2 | 有降级路径的功能缺陷 | 下一版本 |
| P3 | 体验/文案问题 | 排期 |

## 10. 测试记录归档

每次发布在 `docs/testing/records/` 留一份记录：环境、用例、结果、指标、缺陷、结论。模板见 [TEMPLATES.md](../templates/TEMPLATES.md)。
