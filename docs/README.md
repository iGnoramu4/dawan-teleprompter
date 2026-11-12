# 大皖提词器项目 · 文档索引

> 适用版本：v1.5 ｜ 最后更新：2026-11-12 ｜ 维护者：TL
> 本目录是**唯一规范来源**。计划文档负责"做什么、什么时候做"，本目录负责"怎么做、怎么检查"。

## 1. 新人阅读顺序（约 2 小时）

1. [项目落地计划](../提词器项目落地计划.md) 的 §0–§5：产品定位、范围、核心竞争力；
2. [架构说明](./architecture/ARCHITECTURE.md)：模块边界与数据流；
3. [编码规范](./standards/CODING.md)：环境、lint、分层、状态管理、错误与日志；
4. [工程流程](./process/WORKFLOW.md)：分支、提交、版本、发布；
5. [测试规范](./testing/TESTING.md)：测试边界、评测集、真机矩阵；
6. [文档制度](./DOCUMENTATION_POLICY.md)：每个阶段必须产出什么。

跑通环境后，执行 `docs/README.md` 第 4 节的四条命令，再提第一个 PR。

## 2. 文档地图

| 目录 | 文件 | 管什么 | 责任人 |
|---|---|---|---|
| `docs/` | [overview.md](./overview.md) | 面向新访客的项目说明：定位、功能、架构、跟随原理、构建、资源、测试、限制与路线图 | TL |
| | [DOCUMENTATION_POLICY.md](./DOCUMENTATION_POLICY.md) | 文档分类、阶段交付物、更新纪律、版本与责任人 | TL |
| `docs/standards/` | [CODING.md](./standards/CODING.md) | Dart/Flutter 编码、目录命名、分层、Riverpod、错误与日志 | FE |
| | [analysis_options.yaml](./standards/analysis_options.yaml) | lint 规则集（复制到仓库根目录使用） | FE |
| | [NATIVE.md](./standards/NATIVE.md) | Android Kotlin、Windows C++、macOS Swift/ObjC++ 局部规范 | FE |
| | [I18N.md](./standards/I18N.md) | 资源、文案、ARB、字体、国际化 | FE |
| `docs/process/` | [WORKFLOW.md](./process/WORKFLOW.md) | 分支模型、提交信息、版本号、CHANGELOG、发布 | TL |
| | [REVIEW.md](./process/REVIEW.md) | 代码评审清单与门禁 | TL |
| | [DEPENDENCY_POLICY.md](./process/DEPENDENCY_POLICY.md) | 依赖引入、许可证审核、模型权重 | TL |
| `docs/testing/` | [TESTING.md](./testing/TESTING.md) | 单测/组件/集成边界、覆盖率、ASR 评测、真机矩阵、性能基线 | QA |
| | [records/20261106-m1c.md](./testing/records/20261106-m1c.md) | M1-c 测试记录：链路、语音跟随、锁定态、帧耗时 | QA |
| | [records/20261106-m2.md](./testing/records/20261106-m2.md) | M2 测试记录：阅读页字体、体积记录项、启动开销、.tps 导入导出 | QA |
| | [records/20261106-m2-coverage.md](./testing/records/20261106-m2-coverage.md) | M2 覆盖率补齐记录：悬浮窗/权限/浮窗设置测试与剩余缺口 | QA |
| | [records/20261106-m2-remote-server.md](./testing/records/20261106-m2-remote-server.md) | M2 遥控协议与服务端（E6-1）测试记录与未验证项 | QA |
| | [records/20261106-m2-remote-client.md](./testing/records/20261106-m2-remote-client.md) | M2 遥控页与阅读页接入（E6-2/E6-3）测试记录与未验证项 | QA |
| | [records/20261106-m2-external-display.md](./testing/records/20261106-m2-external-display.md) | M2 外接显示（E7-1）测试记录与未验证项 | QA |
| | [records/20261106-m2-qr-scan.md](./testing/records/20261106-m2-qr-scan.md) | M2 扫码配对（E6-2 补充）测试记录与未验证项 | QA |
| | [records/20261106-m2-recording.md](./testing/records/20261106-m2-recording.md) | M2 录制/时间轴/复盘/导出（E8-1..3）测试记录与未验证项 | QA |
| | [records/20261106-m3-release-prep.md](./testing/records/20261106-m3-release-prep.md) | M3 发布准备（治理/文档/许可扫描）测试记录与待决项 | QA |
| | [records/20261109-reader-auto-wrap-match-tolerance.md](./testing/records/20261109-reader-auto-wrap-match-tolerance.md) | 阅读页体验：自动每行字数与语音匹配三档测试记录与未验证项 | QA |
| | [records/20261109-reading-band-stage-a.md](./testing/records/20261109-reading-band-stage-a.md) | 阅读页固定阅读带（阶段 A）：视觉行/阅读带/一阶跟随/位置强调与排版迁移 | QA |
| | [records/20261109-reading-band-stage-b.md](./testing/records/20261109-reading-band-stage-b.md) | 阅读页固定阅读带（阶段 B）：篇尾停止/循环、early arm、重排热替换与 300 ms 验收 | QA |
| | [records/20261109-reading-band-stage-c.md](./testing/records/20261109-reading-band-stage-c.md) | 阅读页固定阅读带（阶段 C）：悬浮窗窗口化迁移、外接屏 bandRatio、遥控 v2 兼容 | QA |
| | [records/20261110-paragraph-text-model.md](./testing/records/20261110-paragraph-text-model.md) | 段落化文本与坐标迁移、开发音频入口、功能栏隐藏：实测通过 / 仅接入未验证 | QA |
| `docs/api/` | [remote-protocol.md](./api/remote-protocol.md) | 局域网遥控 WebSocket 协议 v3：配对、消息、坐标语义、版本兼容与迁移路径 | FE |
| | [display-channel.md](./api/display-channel.md) | 外接显示通道 `tps/display` 契约（E7-1，视觉行坐标） | FE |
| | [recording-timeline.md](./api/recording-timeline.md) | 录制产物契约：WAV 参数、`timeline.json` v2（段落 + 字符）、插值与 SRT 规则 | FE |
| `docs/architecture/` | [ARCHITECTURE.md](./architecture/ARCHITECTURE.md) | 模块划分、依赖方向、关键数据流 | TL |
| | [adr/README.md](./architecture/adr/README.md) | ADR 模板与流程 | TL |
| | [adr/0001-flutter.md](./architecture/adr/0001-flutter.md) | 框架选型 | TL |
| | [adr/0002-asr-engine.md](./architecture/adr/0002-asr-engine.md) | ASR 引擎选型 | ALG |
| | [adr/0003-open-source-license.md](./architecture/adr/0003-open-source-license.md) | 开源协议 | TL |
| | [adr/0004-package-size-and-reader-font.md](./architecture/adr/0004-package-size-and-reader-font.md) | 体积不作为门禁；阅读页字体 | TL |
| | [adr/0005-performance-baseline-snapdragon-8-elite.md](./architecture/adr/0005-performance-baseline-snapdragon-8-elite.md) | 性能基准：中高端 Android | TL |
| `docs/templates/` | [TEMPLATES.md](./templates/TEMPLATES.md) | 需求/设计/接口/测试记录/发布说明/运维手册模板 | TL |
| `docs/design/` | [20261106-reader-state-machine.md](./design/20261106-reader-state-machine.md) | 阅读页起始态、逐行跟随判定、收音角标、段落化文本、固定阅读带、功能栏显隐 | FE |
| | [20261109-reading-band-scroll-model.md](./design/20261109-reading-band-scroll-model.md) | 阅读页固定阅读带 + 视觉行显示与跟随滚动重设计（现状诊断、参照拆解、参数与迁移） | FE |
| | [20261111-icon-directions-round2.md](./design/20261111-icon-directions-round2.md) | 图标方向探索 R2：参考大皖新闻/大皖Plus 的抽象方案、色板与主题关系（**已否决，未采用**） | FE |
| | [20261111-icon-bull-variants.md](./design/20261111-icon-bull-variants.md) | 图标方向 R3：方向 C 语言下的牛头三变体、24/32 px 辨识判读与品牌定位（**已否决，未采用**） | FE |
| | [20261111-icon-bull-phone.md](./design/20261111-icon-bull-phone.md) | 图标方向 R4：牛+手机+阅读姿态的三个取舍方案、24/32/48 px 判读与双轨建议（**已否决，未采用**） | FE |
| | [20261111-icon-workbuddy.md](./design/20261111-icon-workbuddy.md) | 图标方向 R5：拆解 Workbuddy 官方图标语言后重做的三个方向、色相决策与 24/32/48 px 判读（**已否决，未采用**） | FE |
| | [20261106-overlay-window.md](./design/20261106-overlay-window.md) | Android 系统级悬浮提词：权限流程、跨引擎数据流、尺寸与位置记忆 | FE |
| | [20261106-recording-timeline.md](./design/20261106-recording-timeline.md) | 录制/时间轴/复盘的数据流、取舍、失败路径与回滚 | FE |
| `docs/ops/` | [diagnostics.md](./ops/diagnostics.md) | 诊断包导出内容、日志字段与排查流程（M2） | FE |
| | [release-runbook.md](./ops/release-runbook.md) | 三端构建、签名/公证、发布与回滚步骤（M3） | TL |
| | [handover.md](./ops/handover.md) | 交接文档：项目现状、代码结构、关键决策、质量门禁、未验证项、踩坑与待办 | 全员 |
| `docs/releases/` | [README.md](./releases/README.md) | 发布说明命名、归档规则与版本索引 | TL |
| | [0.17.0.md](./releases/0.17.0.md) | 0.17.0 内测发布说明 | TL |
| | [release-checklist.md](./releases/release-checklist.md) | 发布前逐项检查清单与证据要求 | TL/QA |
| `docs/help/` | [user-guide.md](./help/user-guide.md) | 用户手册：导入、阅读、跟随、遥控、录制与导出 | FE/UI |
| | [faq.md](./help/faq.md) | 常见问题与降级说明 | FE/UI |
| | [package-rename.md](./help/package-rename.md) | 包名变更：全新安装与旧数据不迁移说明 | TL |
| `docs/legal/` | [privacy.md](./legal/privacy.md) | 隐私政策（本地优先、零云端） | TL |
| | [permissions-statement.md](./legal/permissions-statement.md) | 用户版权限说明（三端） | FE |
| | [third-party-licenses.md](./legal/third-party-licenses.md) | 第三方组件、字体与模型许可清单 | TL |

## 3. 规范之间的约束关系

```
计划文档（范围/里程碑/WBS）
        │
        ├── ARCHITECTURE.md ──► 决定 packages/ 与依赖方向
        │        └── ADR 记录不可逆决策
        ├── CODING.md / NATIVE.md / I18N.md ──► 约束每日提交
        ├── WORKFLOW.md / REVIEW.md / DEPENDENCY_POLICY.md ──► 约束合并与发布
        ├── TESTING.md ──► 约束门禁与验收
        └── DOCUMENTATION_POLICY.md ──► 约束"什么时候必须写什么文档"
```

- **冲突处理**：计划文档与规范冲突时，以计划文档的范围为准、规范的技术细节为准；两者都需在同一个 PR 内修正。
- **单一事实来源**：权限清单只写在计划文档 §10.11 与 `docs/standards/NATIVE.md` 的引用处；依赖白名单只写在 `DEPENDENCY_POLICY.md`；评测阈值只写在 `TESTING.md` 与计划文档 §3.3。

## 4. 本地必跑命令（提交前）

```bash
cd teleprompter
dart format --output=none --set-exit-if-changed .
cd apps/app && dart analyze --fatal-infos --fatal-warnings . && cd ../..
for p in packages/*; do (cd "$p" && dart analyze --fatal-infos --fatal-warnings .) || exit 1; done
dart run tool/check_imports.dart          # 分层依赖检查
cd apps/app && flutter test --coverage && cd ../..
dart run tool/check_coverage.dart --min 70
```

CI 会重复执行以上命令，并额外运行 `tool/license_scan`。`markdownlint`、链接检查、golden 测试与集成测试尚未接入 CI，列为后续工作。

## 5. 文档状态

| 文档 | 状态 | 下次复核 |
|---|---|---|
| CODING / NATIVE / I18N | 生效 | M1 结束 |
| WORKFLOW / REVIEW / DEPENDENCY_POLICY | 生效 | M2 结束 |
| TESTING | 生效 | M1 结束（补评测集实测数据） |
| ARCHITECTURE / ADR-0001~0003 | 生效 | 每次架构变更 |
| DOCUMENTATION_POLICY / TEMPLATES | 生效 | M3 结束 |

## 6. 开源治理

仓库根目录提供以下公开入口：

- [README](../README.md)：项目定位、特性、构建入口与许可
- [BUILDING](../BUILDING.md)：三端构建、模型权重、图标再生成
- [CONTRIBUTING](../CONTRIBUTING.md) ｜ [CODE_OF_CONDUCT](../CODE_OF_CONDUCT.md) ｜ [SECURITY](../SECURITY.md)
- [LICENSE](../LICENSE) ｜ [NOTICE](../NOTICE) ｜ [MODEL_LICENSE](../MODEL_LICENSE.md) ｜ [TRADEMARK](../TRADEMARK.md)
- [第三方许可清单](./legal/third-party-licenses.md) ｜ [包名变更说明](./help/package-rename.md)
- CI：[.github/workflows/ci.yml](../.github/workflows/ci.yml)
