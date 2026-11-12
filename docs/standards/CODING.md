# Dart / Flutter 编码规范

> 状态：生效（v1.0）｜ 责任人：FE ｜ 复核：M1 结束
> 适用范围：`apps/app`、`packages/*` 的全部 Dart 代码。

## 1. 工具链与版本

| 项 | 规定 | 检查方式 |
|---|---|---|
| Flutter | 3.x stable，版本写入 `.fvmrc`（推荐 FVM） | `flutter --version` 与 `.fvmrc` 一致 |
| Dart | 3.x（随 Flutter） | `dart --version` |
| 格式化 | `dart format`（默认 80 列） | `dart format --output=none --set-exit-if-changed .` |
| 静态检查 | `flutter_lints` + 本项目 `analysis_options.yaml` | `flutter analyze --fatal-infos --fatal-warnings` |
| 依赖锁定 | 提交 `pubspec.lock` | CI 校验 lock 未漂移 |
| 生成代码 | `build_runner` 产物提交仓库（drift/l10n） | CI 重新生成后 `git diff --exit-code` |

**禁止**：手改生成文件（`*.g.dart`、`*.freezed.dart`、`lib/l10n/*.dart`）；提交时格式化未跑。

## 2. Lint 规则集

仓库根 `analysis_options.yaml` 直接复制 [analysis_options.yaml](./analysis_options.yaml)。要点：

- `strict-casts`、`strict-inference`、`strict-raw-types` 全开；
- 禁止 `print`、`dynamic` 隐式推断、未等待的 Future（`unawaited_futures`）；
- 公共 API 必须有 `///` 文档（`public_member_api_docs`，仅 `packages/*` 开启，`apps/app` 关闭）；
- `avoid_print`、`prefer_const_constructors`、`use_super_parameters`、`always_declare_return_types`；
- 例外只能通过行内 `// ignore: <rule> — <原因>`，且必须在 PR 描述里列出。

新增规则需在 PR 中说明收益与影响文件数；一次性大规模改动单独成 PR，不混入功能提交。

## 3. 目录与命名

```
apps/app/lib/
├── main.dart
├── app/                    # 启动、路由、主题装配
├── features/
│   ├── library/            # 台本列表/导入
│   ├── editor/
│   ├── reader/
│   ├── remote/
│   ├── recording/
│   └── settings/
│       ├── presentation/   # Widget、Page、Provider
│       ├── application/    # Controller/Notifier
│       ├── domain/         # 纯 Dart 用例（可无）
│       └── infrastructure/ # 仓储实现、平台适配
└── shared/                 # 跨 feature 的 UI 小组件
```

| 对象 | 规则 | 例 |
|---|---|---|
| 文件/目录 | `snake_case` | `reader_page.dart` |
| 类/枚举/typedef | `PascalCase` | `ReaderController` |
| 变量/方法/参数 | `lowerCamelCase` | `anchorLine` |
| 常量 | `lowerCamelCase`（不用全大写） | `defaultReadAhead` |
| 私有成员 | 前缀 `_` | `_scrollPlanner` |
| Provider | `<名词>Provider`，family 用 `<名词>Family` | `readerControllerProvider` |
| 布尔参数 | 必须具名 | `foo({required bool enabled})` |
| 文件组织 | 一个文件一个公开类；超过 400 行拆分 | — |

## 4. 分层与依赖方向

| 层 | 允许依赖 | 禁止 |
|---|---|---|
| `presentation` | application、design_system、core_models | 直接调 `asr_kit`、`data_store` 实现、平台 API |
| `application` | domain、core_* 接口、Riverpod | `BuildContext`、Widget、`dart:ui` |
| `domain` | `core_models`、纯 Dart | Flutter、平台包、IO |
| `infrastructure` | domain 接口、`data_store`、`tp_platform` | 反向被 domain 依赖 |

- `packages/core_alignment`、`core_scroll`、`core_models` **不得 import Flutter**；CI 用 `dart test` 与 `tool/check_imports.dart` 保证。
- 跨 feature 复用必须下沉到 `packages/` 或 `shared/`；禁止 `features/a` import `features/b`。
- 依赖注入统一走 Riverpod provider；**禁止**全局单例、service locator、静态可变状态。

## 5. 状态管理（Riverpod 2）

| 场景 | 用法 |
|---|---|
| 只读依赖 | `Provider` |
| 可变 UI 状态 | `NotifierProvider` / `AsyncNotifierProvider` |
| 一次性动作 | Controller 内方法，返回 `Future<Result>` |
| 需要参数 | `.family`，参数必须可比较（避免对象相等陷阱） |
| 生命周期 | `autoDispose` 仅用于页面级；会话/引擎常驻用 `keepAlive` |
| 测试 | 用 `ProviderContainer` + override，禁止 mock 全局 |

规则：

1. `build()` 内不做 IO、不启动计时器；副作用放 `init`/显式方法；
2. Widget 只 `ref.watch` 需要的切片，禁止 watch 整个大对象；
3. 不在 `build` 中 `ref.read` 触发状态写入；
4. 异步状态统一 `AsyncValue`，禁止自造 `isLoading` 布尔三件套；
5. 会话状态机（idle/loading/following/paused/error）用 sealed class，不用多个 bool。

## 6. 错误处理

- **分层约定**：
  - `domain` 返回 `Result<T, AppError>`（sealed），不抛业务异常；
  - `infrastructure` 捕获平台/IO 异常，映射为 `AppError`（`PermissionDenied`、`Unavailable`、`ParseFailure`、`StorageFailure`、`NetworkFailure`）；
  - `presentation` 只负责把 `AppError` 转成用户可读文案（走 l10n），不展示堆栈。
- **禁止**：
  - 空的 `catch {}`；
  - `catch (e) { print(e); }`；
  - 用异常控制正常流程；
  - 把原始异常文本直接显示给用户。
- **必须**：每个 `catch` 要么恢复、要么上报到本地日志、要么转换为 `AppError` 继续抛。
- **权限拒绝**：属于 `PermissionDenied`，UI 必须走 §10.11 的降级路径，不得阻塞主流程。

## 7. 日志规范

使用 `logging` 包，统一在 `diagnostics_kit` 暴露 `AppLog`。

| 级别 | 用途 | release 是否保留 |
|---|---|---|
| `severe` | 崩溃、数据损坏、权限致命失败 | 是 |
| `warning` | 降级、重试、模型回退 | 是 |
| `info` | 会话开始/结束、里程碑、指标摘要 | 是 |
| `fine` | 排障细节（对齐窗口、ASR 分段） | 否（debug 才开） |

- 结构化字段：`AppLog.info('session.start', data: {'scriptId': id, 'model': tier, 'platform': p})`；
- **禁止记录**：台本正文、识别原文、音频、token、设备硬件 ID、用户文件路径；
- 允许记录：脚本 id（内部 UUID）、行号、置信度、耗时、模型名、权限状态；
- 日志落盘走 `diagnostics_kit` 的 ring buffer（最近 3 次会话，总量 < 20 MB）；
- release 包默认 `info`，不输出 `debugPrint`。

## 8. 异步与性能

- 对齐 DP、拼音归一化、大文本解析放 Isolate；主 Isolate 单帧预算 **16 ms**；
- 禁止在 `build`/`didUpdateWidget` 中做重计算；用缓存 + `ValueKey`；
- 滚动动画用 `Ticker` + 弹簧积分，禁止每帧 `setState`；
- `const` 构造优先；列表用 `ListView.builder`，长列表不得一次性 build；
- Future 必须 `await` 或 `unawaited()` 显式标注；取消用 `CancelableOperation` 或自建 token；
- 禁止 `Future.delayed` 作为业务同步手段（测试除外）。

## 9. 注释与文档

- `packages/*` 的公开类/方法必须 `///` 文档，说明参数、返回、异常/错误；
- 复杂算法注释写"为什么"与不变量（如"窗口必须单调，否则会回跳"）；
- `TODO` 必须带 issue：`// TODO(#123): 支持竖排`；
- 不写"是什么"的废话注释；不保留注释掉的旧代码。

## 10. 提交前检查表

- [ ] `dart format` 无差异
- [ ] `flutter analyze --fatal-infos` 通过
- [ ] `tool/check_imports.dart` 通过（无跨 feature、无 core 依赖 Flutter）
- [ ] 新增/修改逻辑有单测；核心包覆盖率达标（见 TESTING.md）
- [ ] 无新增硬编码文案（走 l10n）
- [ ] 无新增硬编码颜色/字号（壳层走 design_system 令牌）
- [ ] 日志不含敏感信息
- [ ] 公共 API 有 dartdoc
