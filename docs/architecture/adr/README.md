# 架构决策记录（ADR）

> 状态：生效 ｜ 责任人：TL

## 1. 何时写 ADR

满足任一条件即必须写：

- 不可逆或高成本回退的技术选择（框架、数据库、ASR 引擎、许可）；
- 跨模块的接口/协议约定；
- 影响安全、隐私、分发方式的决策；
- 推翻既有架构规则。

日常实现细节、可随时替换的库不写 ADR（写入 PR 描述即可）。

## 2. 流程

1. 复制 `0000-template.md` 为 `NNNN-<slug>.md`（编号递增，不复用）；
2. 状态：`Proposed → Accepted / Rejected / Superseded`；
3. PR 评审通过后改 `Accepted`，合入；
4. 被替代时在新 ADR 中写 `Supersedes: NNNN`，旧 ADR 状态改 `Superseded`，正文不改写；
5. 索引维护在本文末尾。

## 3. 模板

```markdown
# NNNN. <标题>

- 状态：Proposed | Accepted | Rejected | Superseded by NNNN
- 日期：YYYY-MM-DD
- 决策人：<角色/姓名>
- 关联：<issue/PR/计划文档章节>

## 背景
<问题、约束、现状>

## 决策
<选了什么，一句话说清>

## 备选方案
| 方案 | 优点 | 缺点 | 结论 |

## 影响
<正面/负面后果、成本、迁移、风险>

## 验证方式
<如何证明决策有效：指标、测试、原型>
```

## 4. 索引

| 编号 | 标题 | 状态 | 日期 |
|---|---|---|---|
| [0001](./0001-flutter.md) | 采用 Flutter 作为三端 UI 框架 | Accepted | 2026-11-06 |
| [0002](./0002-asr-engine.md) | ASR 引擎：sherpa-onnx 主 + Vosk 兜底 + whisper.cpp 离线精对齐 | Accepted | 2026-11-06 |
| [0003](./0003-open-source-license.md) | 采用 Apache-2.0 全量开源 | Accepted | 2026-11-06 |
| [0004](./0004-package-size-and-reader-font.md) | 取消包体门禁；阅读页嵌入完整思源黑体超粗体 | Accepted | 2026-11-06 |
| [0005](./0005-performance-baseline-snapdragon-8-elite.md) | 性能基准定位为中高端 Android（骁龙 8 Elite / 12 GB） | Accepted | 2026-11-06 |
