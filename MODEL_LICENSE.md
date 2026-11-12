# 模型权重许可与分发

> 状态：生效（分发方式已定稿）｜ 责任人：ALG/TL ｜ 更新：2026-11-06
> 决策：**A+B** —— 随安装包分发 T0 档，同时保留用户本地导入方式（2026-11-06）。
> 原则：模型权重不纳入代码的 Apache-2.0 许可，按各自上游许可单独授权；权重文件不进入 Git 仓库。

## 1. 分发规则

| 方式 | 规则 |
|---|---|
| A. 随包分发 | 构建前按 [`teleprompter/tool/models.lock.json`](teleprompter/tool/models.lock.json) 的 URL/SHA256 获取并校验，注入 `teleprompter/apps/app/assets/models/<id>/`；打包后随 APK 分发 |
| B. 本地导入 | 用户从本机选择模型目录，应用校验文件完整性与版本后加载；不随包分发，不需要额外许可授权 |
| Git | 仅提交清单与许可文本；`*.onnx` 与模型目录由 `.gitignore` 排除 |
| 构建 | 缺少权重时构建脚本失败并提示，不允许产出「声明有模型但实际缺失」的包 |
| 回退 | 若某档上游许可不允许再分发，该档改为仅 B；A 档不降级为静默下载 |

## 2. A 档随包清单（T0）

模型 id：`zipformer-zh-14M-int8`，路径 `teleprompter/apps/app/assets/models/zipformer-zh-14M-int8/`。

| 文件 | 大小（bytes） | SHA256 |
|---|---|---|
| `encoder-epoch-99-avg-1.int8.onnx` | 21,621,684 | `1c556ea57cec304e55ec4b72e52c1cc098bb01476ed7d90f3de939fe126487b1` |
| `decoder-epoch-99-avg-1.int8.onnx` | 1,888,682 | `22f123bb8cba9b38974b3df18a3f45e7081f4985ebb2e075d9f21f618c468bbf` |
| `joiner-epoch-99-avg-1.int8.onnx` | 1,795,562 | `a7cf9d82757bdcf786059454495a9ca95e4bd7347f72473fc08d794475c36169` |
| `tokens.txt` | 48,697 | `8b294db9045d6e5f94647f4c1eec1af4da143a75053c399611444b378ff966ac` |

合计约 25,354,625 bytes（约 24.2 MiB）。

## 3. 许可与核对

### 3.1 代码框架

`sherpa-onnx` 框架为 Apache-2.0；**框架许可不等于权重许可**。

### 3.2 分发许可

| 项 | 状态 |
|---|---|
| 随包分发（A） | 已由项目负责人决策采用；发布前需确认上游模型卡允许再分发 |
| 本地导入（B） | 不需要再分发授权；仅需在应用内说明来源与许可 |
| 商用 | 以模型卡为准；若模型卡限制商用，则不得随包分发 |

### 3.3 发布门禁（ALG 回填）

发布前必须逐项记录：模型卡/发布页 URL、许可标识、是否允许商用与再分发、是否需要署名、训练数据限制。核对结果写入本节后再上传 Release；未核对不得发布 A 档。

**14M 回填（2026-11-10 复核）**

| 项 | 结果 |
|---|---|
| 模型卡 URL | https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23 |
| 许可标识 | **Apache-2.0** |
| 允许商用 | 是（Apache-2.0） |
| 允许再分发 | 是，需保留版权声明、许可文本与 NOTICE |
| 需要署名 | 是（保留上游版权与许可） |
| 训练数据 | WenetSpeech，仅中文；无英文 BPE |
| 结论 | **可随包（A 档）** |

**双语混合变体回填（2026-11-10 复核）**

| 项 | 结果 |
|---|---|
| 模型卡 URL | https://huggingface.co/csukuangfj/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20 |
| 许可标识 | **Apache-2.0** |
| 允许商用 | 是（Apache-2.0） |
| 允许再分发 | 是，需保留版权声明、许可文本与 NOTICE |
| 需要署名 | 是（保留上游版权与许可） |
| 训练数据 | 中英双语（详见上游模型卡） |
| 修改说明 | encoder 使用上游 int8；decoder/joiner 使用上游 fp32；仅组合与重命名，未再训练 |
| 结论 | **可随包（A 档）**；0.23.0 起为语音跟随默认模型 |

## 4. B 档本地导入规则

| 项 | 要求 |
|---|---|
| 入口 | 用户在设置中选择模型目录；目录需包含 `encoder`/`decoder`/`joiner` 与 `tokens.txt` |
| 校验 | 文件存在性、大小与版本标记；失败时提示缺失项，不进入跟随 |
| 隔离 | 导入模型复制到应用私有目录 `asr_models/<id>/`，不修改用户原目录 |
| 隐私 | 模型仅在本机加载；音频与文本不上传 |
| 版本 | 模型 id 与文件命名与 A 档一致；不兼容版本明确拒绝 |
| 实现状态 | v0.17.0 仅内置 A 档；B 档入口待实现，发布说明不得宣称已支持 |

## 5. 发布前检查

- [ ] `teleprompter/tool/models.lock.json` 与随包文件 SHA256 一致
- [ ] `NOTICE §3` 与本节信息一致（id、文件、许可、大小）
- [ ] 模型卡核对结果已写入 §3.3，且允许当前分发方式
- [ ] 安装包内权重可被 `ModelInstaller` 正常解包（飞行模式实测）
- [ ] B 档未实现时，发布说明与 FAQ 不宣称支持
- [ ] 隐私说明明确「音频与文本不出本机」
- [ ] 新候选进入 A 档前，§6 的「再分发结论」已逐项核对并回填

## 6. 候选模型许可结论（2026-11-10）

> 背景：用户已拍板「必须支持中英混说 + 模型随包分发（A 档），但许可不明或非宽松许可一律不进包，改本地导入」。
> 下表是当前候选的许可结论；**体积与 RTF 为公开资料/估计，最终以实测为准**。任何候选进入 A 档必须先把「再分发结论」从「待核」改为「允许」。

### 6.1 逐项结论

| 候选 | 体积（int8 估计） | 流式 | 热词 | 权重许可 | 再分发结论 | 依据 / 状态 |
|---|---|---|---|---|---|---|
| zipformer-zh-14M（现用） | ~24 MiB | 是（chunk 32≈320 ms） | 是 | **Apache-2.0** | **允许（A 档）** | 已查证：HF 模型卡；仅中文、无英文 BPE |
| zipformer bilingual zh-en（80M 级） | ~198 MB 仓库 | 是 | 是（`modified_beam_search`） | **Apache-2.0** | **允许（A 档）** | 已查证：HF 模型卡标注 Apache-2.0；双语、支持热词 |
| streaming zipformer small CTC zh 2025 | ~25 MB | 是 | 否（CTC 不支持热词） | 待核 | **待核，暂不进包** | 需回填上游模型卡与训练数据许可 |
| streaming zipformer large CTC zh | ~155 MB | 是 | 否 | 待核 | **待核，暂不进包** | 同上 |
| streaming Paraformer zh | ~226 MB（158+68） | 是 | 否 | 镜像标 Apache-2.0，上游待核 | **待核，暂不进包** | 需追溯上游 FunASR 权重许可 |
| SenseVoiceSmall | ~228 MB | 否（整段） | 否 | **`model-license`（自定义）** | **不允许直接随包（默认 B 档）** | 已查证：HF 模型卡 License 字段为 `model-license`；商用/再分发需单独评审 |
| Whisper large-v3-turbo | ~1.6 GB | 否 | 否 | **MIT** | 允许，但**仅离线/二遍** | 已查证：HF 模型卡 MIT；体积与延迟不适合实时跟随 |

### 6.2 A 档白名单（可随包）

只有同时满足以下条件才可加入：

1. 权重许可为 Apache-2.0 / MIT / BSD 等宽松许可，或已取得明确的再分发书面授权；
2. 上游模型卡明确允许商用；
3. 体积、SHA256 已写入 `teleprompter/tool/models.lock.json`；
4. `NOTICE` 已补充版权与许可文本。

当前白名单：`zipformer-zh-14M-int8`、`zipformer-bilingual-mixed`（0.23.0 起随包，体积与 SHA256 已回填 `teleprompter/tool/models.lock.json`）。

### 6.3 B 档（本地导入）范围

- 许可不明、非宽松许可、或商用受限的权重：一律只走 B 档；
- 用户自行导入的模型不随包分发，应用只负责完整性校验与来源说明；
- SenseVoice 在许可评审通过前，只能作为 B 档候选，不得写入 A 档清单。
