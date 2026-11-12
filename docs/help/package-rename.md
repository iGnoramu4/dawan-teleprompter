# 包名变更说明

自 0.26.0 起，应用包名由 `com.tp.prompter.teleprompter` 变更为 `com.dawan.teleprompter`（Android `applicationId`/`namespace` 与 macOS Bundle Identifier 同步调整）。0.25.0 及更早版本仍使用旧包名。

换包名后是**全新安装**，旧包数据（台本、设置、录音、日志、已解包模型）**不迁移**，卸载旧包后不再可用。

- 旧包名：`com.tp.prompter.teleprompter`
- 新包名：`com.dawan.teleprompter`
- 跨设备配对与局域网遥控的 `tps` 协议前缀保持不变。
