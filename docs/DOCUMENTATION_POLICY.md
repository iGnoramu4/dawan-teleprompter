# 文档体系与文档纪律

> 状态：生效 ｜ 责任人：TL ｜ 复核：M3 结束
> 目标：让"每个阶段该产出什么文档、代码变更该同步什么文档"可检查，而不是靠自觉。

## 1. 文档分类与存放位置

| 类型 | 目录 | 命名 | 责任人 | 评审人 | 生命周期 |
|---|---|---|---|---|---|
| 需求 | `docs/requirements/` | `YYYYMMDD-<slug>.md` | 产品 | TL、QA | 每版本新建，旧版标 superseded |
| 设计 | `docs/design/` | `YYYYMMDD-<slug>.md` | TL/FE | 模块负责人 | 随实现更新 |
| 接口 | `docs/api/` | `<module>.md` | 模块负责人 | FE/ALG | 契约变更必更新 |
| ADR | `docs/architecture/adr/` | `NNNN-<slug>.md` | 决策人 | TL | 不可变，替代时新建 |
| 测试记录 | `docs/testing/records/` | `YYYYMMDD-<milestone>.md` | QA | TL | 归档，不改写 |
| 发布说明 | `docs/releases/` | `<version>.md` | TL | 产品 | 发布后归档 |
| 运维手册 | `docs/ops/` | `<topic>.md` | TL/QA | 支持人员 | 按需更新 |
| 规范 | `docs/standards/`、`docs/process/`、`docs/testing/TESTING.md` | 固定名 | 各责任人 | TL | 版本化管理 |
| 模板 | `docs/templates/` | 固定名 | TL | — | 变更需评审 |
| 索引 | `docs/README.md` | 固定名 | TL | — | 新增文档必须更新 |

> 文档正文使用 Markdown；图用 Mermaid 或 PNG（PNG 放 `docs/assets/`，需注明来源）。

## 2. 每个阶段必须产出什么

| 阶段 | 必须产出 | 门禁 |
|---|---|---|
| M0 技术验证 | 需求（P0 范围）、设计（识别/对齐/滚动）、ADR-0001/0002、M0 实测报告、接口（通道契约初稿）、评测集说明 | 缺任一不进 M1 |
| M1 MVP | 设计（导入/编辑/悬浮窗）、接口（遥控协议、`.tps` 格式）、测试记录（M1）、更新 CHANGELOG | 缺任一不发 M1 演示 |
| M2 内测 | 设计（录制/外接屏）、运维手册（诊断包）、测试记录（M2）、权限清单核对表 | 缺任一不进内测 |
| M3 发布 | 发布说明、运维手册（发布 runbook）、测试记录（发布）、`NOTICE`/`MODEL_LICENSE`、用户手册/FAQ | 缺任一不发布 |
| v1.x 迭代 | 需求增量、设计增量、发布说明、CHANGELOG | 按 PR 检查 |

**轻量原则**：单一功能改动不写独立设计文档，写入 PR 描述；只有跨模块、影响接口/数据/安全时才建 `docs/design/`。

## 3. 文档状态与版本

- 状态：`draft → reviewed → approved → superseded`；
- 只有 `approved` 的文档可作为实现依据；
- 文档内不写"版本历史"表，版本由 Git 历史 + 头部 `updated` 表达；
- 归档文档不删除，状态改 `superseded` 并指向新文档。

## 4. 代码变更 → 文档同步矩阵（评审必查）

| 代码变更 | 必须同步 | 可延后 |
|---|---|---|
| 新增/修改权限、网络行为 | `docs/permissions.md`、计划文档 §10.11、发布说明 | — |
| 变更通道/协议/`.tps` 格式 | `docs/api/<module>.md`、兼容说明 | — |
| 变更模块边界/依赖方向 | `ARCHITECTURE.md`；不可逆则新增 ADR | — |
| 新增依赖/模型/素材 | `NOTICE`、`MODEL_LICENSE.md`、`DEPENDENCY_POLICY` 记录 | — |
| 新增用户可见文案 | ARB（中英）、`I18N.md` 若新增规则 | — |
| 新增/修改主题令牌、组件 | `design_system`、§19 设计规范、golden | — |
| 修改错误码/日志字段 | 接口文档、`CODING.md` 日志表 | — |
| 纯重构/性能优化（行为不变） | `CHANGELOG` 的 Changed（可选） | 设计文档 |
| 缺陷修复 | `CHANGELOG` 的 Fixed | 发布说明（重要缺陷） |

## 5. 评审时的文档检查项

- [ ] PR 描述"文档影响"已填写；
- [ ] 上述矩阵涉及的文档已更新；
- [ ] 新增文档已加入 `docs/README.md` 索引；
- [ ] 文档头信息（owner/status/updated）完整；
- [ ] 文档中的命令、阈值、路径可直接执行/核对，不是口号；
- [ ] 链接有效（CI `lychee` 检查）。

## 6. 版本与责任人

| 角色 | 文档职责 |
|---|---|
| 产品 | 需求、发布说明（用户视角） |
| TL | 架构、ADR、流程规范、索引、发布 runbook |
| FE | 编码/原生/i18n 规范落地、设计文档、接口文档 |
| ALG | ASR/对齐设计、ADR-0002、评测报告 |
| QA | 测试规范、测试记录、真机矩阵 |

- 每份文档只有一个 owner；owner 变更需在 PR 中说明；
- 文档过期由 owner 负责修正；CI 每月检查 `updated` 超过 90 天且状态为 approved 的文档，输出提醒（不阻塞）。

## 7. 工具与检查

```bash
# Markdown 风格与结构
npx markdownlint-cli2 "docs/**/*.md"

# 链接与锚点
lychee docs/README.md docs/**/*.md

# API 文档（dartdoc）
dart doc packages/core_alignment packages/core_scroll
```

CI 对 `docs/**` 的 PR 运行上述三项；失败即需修复。`dartdoc` 产物发布到静态站点（可选，v1.0 后）。

## 8. 文档的最小质量要求

1. 每份文档开头有头信息与一句话目的；
2. 命令可复制执行，路径真实存在；
3. 阈值是数字，不是"尽量""适当"；
4. 决策有备选与取舍，不只有结论；
5. 不复制大段第三方闭源内容；引用只写设计思路与参数（见计划文档 §5.10）。
