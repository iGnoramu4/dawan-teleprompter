# 贡献指南

> 状态：生效 ｜ 责任人：TL ｜ 更新：2026-11-06
> 本项目采用 Apache-2.0 许可（见 [LICENSE](./LICENSE)）；提交前请阅读 [docs/README.md](./docs/README.md) 的规范索引。

## 1. 开发环境

| 项 | 要求 |
|---|---|
| Flutter | 3.47.9 stable（见 `.fvmrc`；本机 SDK 路径以实际安装为准） |
| Dart | 随 Flutter 附带（Dart 3） |
| 平台 | Android SDK、Xcode（macOS）、Visual Studio（Windows）按目标端安装 |
| 工作区 | 路径可含空格；本仓库已在含空格的挂载路径下验证可构建与测试 |

首次准备：

```bash
cd teleprompter
flutter pub get
cd apps/app && flutter pub get
dart run build_runner build --delete-conflicting-outputs   # 修改 drift 表后
```

## 2. 提交前四检（必须全绿）

```bash
cd teleprompter
# 仓库根（teleprompter/）
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos --fatal-warnings       # 或在 apps/app、改动的包内执行
dart run tool/check_imports.dart
cd apps/app && flutter test --coverage
cd ../.. && dart run tool/check_coverage.dart --min 70
```

- 覆盖率阈值 **70%**，不得下调，不得用排除文件的方式刷指标；
- `core_*` 包不得依赖 Flutter 或平台插件；
- 新增/修改依赖需同步 `NOTICE` 与 `docs/process/DEPENDENCY_POLICY.md`；
- 新增用户可见文案需同步 `app_zh.arb` / `app_en.arb`。

## 3. 分支与提交

- 分支：`feat/<slug>`、`fix/<slug>`、`docs/<slug>`、`chore/<slug>`；从 `main` 拉出，Squash merge；
- 提交信息遵循 Conventional Commits（`feat(reader): ...`），详见 [WORKFLOW.md](./docs/process/WORKFLOW.md)；
- 所有提交必须带 DCO 签署：

```bash
git commit -s -m "feat(reader): add ..."
```

- 不接受 CLA；贡献者保留版权，按 Apache-2.0 授权。

## 4. PR 要求

| 项 | 要求 |
|---|---|
| 描述 | 为什么改、影响面、验证方式（命令与结果） |
| 关联 | 关联 issue/计划任务 ID（如 E8-1） |
| 文档影响 | 按 [DOCUMENTATION_POLICY §4](./docs/DOCUMENTATION_POLICY.md) 填写 |
| 测试 | 新增行为必须有对应单测/组件测试；缺陷修复优先补回归用例 |
| 只读文件 | 不得修改 `提词器项目规划方案.md`、`提词器项目落地计划.md` 与目录内 APK |

## 5. 代码与文档规范

- 编码/分层/日志：[CODING.md](./docs/standards/CODING.md)
- 原生（Kotlin/Swift/C++）：[NATIVE.md](./docs/standards/NATIVE.md)
- 国际化：[I18N.md](./docs/standards/I18N.md)
- 测试边界与真机矩阵：[TESTING.md](./docs/testing/TESTING.md)

## 6. 安全与行为

- 漏洞报告见 [SECURITY.md](./SECURITY.md)；
- 社区行为见 [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)；
- 名称与标识使用见 [TRADEMARK.md](./TRADEMARK.md)。
