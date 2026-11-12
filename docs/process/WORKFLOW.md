# 工程流程规范：分支、提交、版本与发布

> 状态：生效 ｜ 责任人：TL ｜ 复核：M2 结束

## 1. 分支模型（主干开发 + 短分支）

| 分支 | 用途 | 生命周期 | 保护 |
|---|---|---|---|
| `main` | 始终可构建、可发布 | 永久 | 禁直推；需 PR + 1 批准 |
| `feat/<slug>` | 功能 | ≤ 5 天 | — |
| `fix/<slug>` | 缺陷 | ≤ 3 天 | — |
| `docs/<slug>` | 文档 | ≤ 3 天 | — |
| `chore/<slug>` | 构建/依赖/工具 | ≤ 3 天 | — |
| `release/<x.y>` | 发布冻结与回归 | 2–3 周 | 只允许 `fix/*` 与版本提交 |
| `hotfix/<x.y.z>` | 线上严重缺陷 | ≤ 1 天 | 从 tag 拉出，合回 main 与 release |

规则：

- 分支名小写、连字符分词；不建长期 `develop`；
- 合并方式：**Squash merge**，保留单一提交与 PR 号；
- 合并前必须 rebase 到 `main` 最新，禁止 merge commit 污染历史；
- 发布冻结期 `main` 只接受 release 相关修复。

## 2. 提交信息（Conventional Commits）

格式：

```
<type>(<scope>): <subject>

<body: 为什么改、影响面、风险>

<footer: Signed-off-by / Refs / BREAKING CHANGE>
```

| type | 用途 |
|---|---|
| `feat` | 新功能 |
| `fix` | 缺陷修复 |
| `perf` | 性能优化 |
| `refactor` | 不改变行为的重构 |
| `test` | 测试 |
| `docs` | 文档 |
| `build` | 构建/依赖 |
| `ci` | 流水线 |
| `chore` | 杂项 |
| `revert` | 回滚 |

- `scope` 取包名或模块：`core-alignment`、`asr-kit`、`reader`、`android`、`ci`、`docs`；
- subject ≤ 72 字符，祈使句，不以句号结尾；
- 破坏性变更必须写 `BREAKING CHANGE:` 或在 type 后加 `!`；
- 所有提交必须带 DCO 签署：

```bash
git commit -s -m "feat(reader): add look-ahead line control"
```

生成的行：`Signed-off-by: Name <email>`。

### 工具与命令

- `commitlint`（`@commitlint/cli` + `@commitlint/config-conventional`），配置 `commitlint.config.mjs`；
- `lefthook` 管理钩子（不引入 husky/node 运行时依赖到应用）：

```yaml
# lefthook.yml
commit-msg:
  commands:
    commitlint:
      run: npx commitlint --edit {1}
pre-commit:
  commands:
    format:
      run: dart format --output=none --set-exit-if-changed .
    analyze:
      run: flutter analyze --fatal-infos --fatal-warnings
pre-push:
  commands:
    test:
      run: flutter test
```

CI 校验（PR 内全部提交）：

```bash
npx commitlint --from origin/main --to HEAD
```

## 3. 代码评审

- 每个 PR 至少 1 名评审人；`core_alignment`、`asr_kit`、`tp_platform`、安全相关变更需 2 人；
- PR 模板必须填写：改了什么、为什么、怎么验证、影响文档、风险与回滚；
- 评审清单见 [REVIEW.md](./REVIEW.md)；
- 评审时限：普通 PR 1 个工作日内首评；发布冻结期 4 小时内。

## 4. 版本号与发布命名

采用 **SemVer**：`MAJOR.MINOR.PATCH`。

| 版本 | 含义 |
|---|---|
| `1.0.0` | 首个正式版（M3 出口） |
| `1.0.x` | 缺陷修复，无新功能 |
| `1.x.0` | 新功能，向下兼容 |
| `2.0.0` | 破坏性变更（数据格式/协议） |

- Git tag：`v1.0.0`（附注 tag，含发布说明）；
- Android：`versionName = 1.0.0`，`versionCode` 单调递增（规则：`MAJOR*10000 + MINOR*100 + PATCH`，如 10000）；
- 构建号：CI 内 `BUILD_NUMBER`，写入安装包元数据，不参与语义；
- 产物命名：

```
teleprompter-1.0.0-android-arm64.apk
teleprompter-1.0.0-windows-x64.msix
teleprompter-1.0.0-macos-universal.dmg
```

- 预发布：`1.0.0-beta.1`（仅内部/测试渠道，不对外称正式版）。

## 5. CHANGELOG

- 格式遵循 Keep a Changelog；文件根目录 `CHANGELOG.md`；
- 由 `git-cliff` 从 Conventional Commits 生成：

```bash
git cliff --config cliff.toml --unreleased --prepend CHANGELOG.md
```

- 结构：`Added / Changed / Fixed / Removed / Security / Docs`；
- 每条写**用户可感知的变化**，不写内部重构细节（内部变更归入 `Changed` 简述）；
- 发布时必须把 `Unreleased` 改为版本号 + 日期；
- 破坏性变更必须在 `Changed` 下显式标注 `BREAKING`。

## 6. 发布流程（M3 及之后）

1. 从 `main` 拉 `release/<x.y>`；
2. 冻结功能，只修 P0/P1 缺陷；
3. 跑完整门禁（TESTING.md §6 + 计划文档 §14.4）；包体只记录、不设阈值、不阻塞发布（见 TESTING.md §6 决策说明）；
4. 更新版本号、`CHANGELOG.md`、`NOTICE`、`MODEL_LICENSE.md`；
5. 打 tag → CI 构建三端产物 → 签名/公证；
6. 产物哈希写入发布说明，上传制品库与发布页；
7. `release` 合回 `main`，删除分支；
8. 发布后 48 小时热修窗口，`hotfix/x.y.z` 从 tag 拉出。

## 7. 回滚

- 应用版本回滚：保留上一版安装包与签名，发布页同时提供 `x.y.(z-1)`；
- 数据回滚：升级前自动备份（drift 导出），迁移失败自动还原；
- 回滚必须更新 `CHANGELOG` 的 `Security`/`Fixed` 并说明原因。
