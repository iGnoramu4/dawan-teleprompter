# 诊断包与日志排查手册

> 状态：生效 ｜ 责任人：FE ｜ 更新：2026-11-06 ｜ 适用：`0.17.0+2020`
> 目的：让支持人员按固定步骤获取日志与运行参数，定位问题时不依赖用户口述。

## 1. 日志位置与格式

| 项 | 值 |
|---|---|
| 路径 | 应用私有目录 `logs/app-YYYYMMDD.jsonl`（`AppLog.init` 注入） |
| 格式 | 每行一个 JSON：`{"ts":"ISO8601","tag":"...","event":"...",...}` |
| 写入 | `IOSink` 追加；写盘失败静默丢弃，不影响提词 |
| 内存保留 | 最近 200 条（`AppLog.recent`） |
| 读取范围 | 仅当天文件（`readAll`），不跨天聚合 |

`tag` 常见取值：`app`（启动/日志）、`reader`（阅读、设置、帧耗时）、`settings`（导出结果）、`remote`（遥控连接与命令）。

## 2. 导出诊断包

入口：设置页 → 「诊断」→「导出诊断包」。

导出内容（单个 `.txt`）：

```text
# teleprompter diagnostics
{"exportedAt":"...","platform":"android|macos|windows","osVersion":"...","readerDefaults":{...}}
# logs
<当日 JSONL 原文>
```

- 文件名 `teleprompter-diag-<UTC 去分隔符时间戳>.txt`；
- 走系统「另存为」；取消则提示已取消，不写文件；
- 头信息只含导出时间、平台、系统版本与阅读默认参数，**不写本地路径、账号、台本内容**（CODING §7）；
- 导出结果仅记录 `ok` / `cancelled`，不记录保存路径。

## 3. 排查流程

1. 让用户复现问题后立即导出（只保留当天日志，跨天会丢上下文）；
2. 先看 `ts` 与 `tag` 定位时间线，关注 `error`/`failed` 字段；
3. 阅读页问题看 `reader` 的 `open`、`settings_loaded`、`frame_summary`；
4. 遥控问题看 `remote`：`server_started`、`hello`、`command`、`closed`（关闭码含义见 [remote-protocol.md](../api/remote-protocol.md)）；
5. 录制/复盘问题：时间轴与音频文件在应用私有目录 `recordings/`，诊断包**不包含**音频，需用户主动从「录制历史」导出；
6. 悬浮窗问题：确认 `SYSTEM_ALERT_WINDOW` 是否授予，必要时让用户重开一次浮窗并复现。

## 4. 隐私与合规

- 日志与诊断包仅在本机生成，只有用户主动导出才会离开设备；
- 不采集设备唯一标识、位置、联系人；
- 用户把诊断包发给支持人员前，应知悉其中包含运行日志（不含台本正文）；
- 发布前复核导出内容字段，禁止新增路径/账号类字段。

## 5. 已知限制

| 项 | 说明 |
|---|---|
| 跨天日志 | 只导出当天；需要历史时由用户保留多份诊断包 |
| 崩溃日志 | 当前无崩溃上报；崩溃排查依赖系统日志（Android `logcat`、macOS Console、Windows 事件查看器），见发布 runbook |
| 录制音频 | 不进诊断包，避免体积与隐私问题 |
| 帧耗时 | 只有阅读页采样摘要，非完整 trace |
