# 双语 zipformer（A 档）接入前期准备

> 状态：**只做前期准备，不换包、不下载权重** ｜ 更新：2026-11-10
>
> 目标模型：`zipformer-bilingual-zh-en-2023-02-20`（int8 transducer，Apache-2.0）
>
> 前置决策：D1 必须支持中英混说、D2 随包分发（A 档）、D3 低延迟优先、D4 音频采集可调。
>
> 本文中每一项都标注了证据等级：**【查证】**（模型仓库/官方资料可直接核对）、**【估计】**（按公开数据推算）、**【需实测】**（只能在目标设备上得到）。

---

## 1. 结论（TL;DR）

1. **体积**：int8 解码所需 4 个文件合计 **198,270,793 B ≈ 198.3 MB（189.1 MiB）**【查证，HF 文件树】。APK 增量按打包压缩情况估计 **180–200 MB**【估计】；A 档是「所有用户都付这份体积」，这是本项目最大的一次分发代价。
2. **内存**：常驻权重 ≈ 198 MB，加 ONNX Runtime 会话与激活值，估计 **PSS 增量 220–320 MB、峰值 < 500 MB**【估计】。SM8750/12 GB 可承受，但与录制、对齐、UI 并存时需实测。
3. **RTF**：同机同线程下相对现有 14M 约 **5–8 倍**；14M 宿主实测 RTF 0.0256，故双语宿主估计 **0.13–0.21**【估计】；SM8750 上估计 **0.15–0.35**【估计，需实测】。实时余量仍足够，但首字延迟会变长，需按 D3 用数据判断。
4. **接入改造量小**：同结构 streaming transducer，新增一个 `AsrModelSpec` + assets 目录 + pubspec 资源声明即可；不需要改 `asr_engine.dart` 的解码链路。
5. **切换前必须先解决**：英文输出的大小写与归一化匹配、`tokens.txt` 的 sha256 回填、首次解包耗时、以及真机 RTF/PSS。**在这些数据回来之前不替换默认模型。**

---

## 2. 体积与分发代价

### 2.1 文件清单【查证】

来源：HF 仓库 `csukuangfj/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20` 文件树（2026-11-10 拉取）。

| 文件 | 字节 | 说明 |
|---|---:|---|
| `encoder-epoch-99-avg-1.int8.onnx` | 181,895,032 | encoder，占总体积 92% |
| `decoder-epoch-99-avg-1.int8.onnx` | 13,091,040 | decoder |
| `joiner-epoch-99-avg-1.int8.onnx` | 3,228,404 | joiner |
| `tokens.txt` | 56,317 | 词表（含英文 BPE 片段） |
| **合计** | **198,270,793** | ≈ 198.3 MB / 189.1 MiB |

- 仓库里另有 fp32 版（encoder 330 MB、decoder 13.9 MB、joiner 12.8 MB）与 `bpe.model`（245 KB）。**解码不需要 `bpe.model`**；A 档只带 int8 三件套 + `tokens.txt`【查证：sherpa-onnx 流式 transducer 只需这 4 个文件，与现有 14M 用法一致】。
- 现有 14M 四件套合计 25,345,425 B（≈ 24.2 MiB），**体积放大 7.82 倍**。

### 2.2 分发影响

| 项 | 现状（14M） | 换双语后 | 证据 |
|---|---:|---:|---|
| 模型资产 | 24.2 MiB | 189.1 MiB | 【查证】 |
| APK 增量 | — | +180–200 MB【估计】 | 取决于 aapt 是否压缩 `.onnx`，**需实测** |
| 首次启动解包 | 现有链路 < 1 s【需实测确认】 | 估计 2–6 s【估计】 | `ModelInstaller.ensure` 逐文件 `rootBundle.load` + 写盘，198 MB 在 UFS 上受读放大影响 |
| 后续启动 | 直接读已解包文件 | 同左（marker 命中） | 现有实现 |
| 应用私有目录占用 | ≈ 24 MB | ≈ 198 MB + 旧模型（若保留回退） | 需在「存储」说明中告知用户 |

> 回退策略要求同时保留 14M，设备上会多占 ≈ 24 MB；若采用「二选一下载」则违反 D2（A 档随包），不采用。

---

## 3. 内存与 RTF 预估

### 3.1 推算依据

- 现有 14M：宿主（macOS x64 / Rosetta）RTF **0.0256**，单线程；真机数据仍缺（SM8750 环境阻塞）。
- 参数量：14M → 80M 级，约 5.7 倍；int8 文件体积 7.82 倍（词表与结构差异）。
- sherpa-onnx 的 RTF 近似随「encoder 计算量」线性增长，故按 5–8 倍区间估计。

| 指标 | 14M（现有） | 双语 80M（估计） | 证据 |
|---|---:|---:|---|
| 宿主 RTF（单线程） | 0.0256（实测） | 0.13–0.21 | 【估计】按 5–8× 推算 |
| SM8750 RTF（单线程） | 待实测 | 0.15–0.35 | 【估计】ARM + int8 算子效率低于 x64 |
| 模型权重常驻 | ≈ 24 MB | ≈ 198 MB | 【查证】文件体积 |
| PSS 增量 | 待实测 | 220–320 MB | 【估计】权重 + ORT 会话 + 激活值 |
| 冷启动加载（已解包） | 待实测 | 0.8–2.0 s | 【估计】ORT 初始化 + 权重映射 |
| 首字延迟增量 | 基线 | +80–250 ms | 【估计】每帧解码更慢；端点参数不变时，算法分块延迟同量级（两者默认 chunk 32≈320 ms） |

> 注意：RTF 0.35 时单核余量约 2.9×，但首字延迟会明显变差；**D3 要求以真机首字延迟与跟随延迟决定是否接受**，不以 RTF 单项通过为准。

### 3.2 需要在真机上取的数

1. `tool/eval_device` 跑同一 10 段，记录 RTF 分布（P50/P95）与冷/热启动加载时间；
2. `dumpsys meminfo` 的 PSS（空载 / 识别中 / 30 min 后）；
3. 端到端首字延迟（拍手 + 录屏逐帧对时），与 14M 同机同脚本对照；
4. 首次解包耗时（清数据后首启，`AppLog` 的 `asr/ready.loadMs` 不覆盖解包，需要单独埋点或看首启总时长）。

---

## 4. 接入改动清单（准备阶段只登记，不落地）

| # | 改动 | 位置 | 说明 |
|---|---|---|---|
| 1 | 新增模型 spec | `packages/asr_kit/lib/src/model_installer.dart` | `AsrModelSpec.bilingualZhEnInt8`：id=`zipformer-bilingual-zh-en-int8`，assetDir=`assets/models/zipformer-bilingual-zh-en-int8`，四个文件名同上；`modelType` 留空由 sherpa 读元数据 |
| 2 | 资产目录 | `apps/app/assets/models/zipformer-bilingual-zh-en-int8/` | 权重不入 Git；`.gitignore` 已忽略 `assets/models/**/*.onnx`，**`tokens.txt` 需补忽略规则**（见 §5.3） |
| 3 | 资源声明 | `apps/app/pubspec.yaml` | `flutter.assets` 增加该目录；漏加会在 `rootBundle.load` 抛 `Unable to load asset` |
| 4 | 选择逻辑 | 建议 `VoiceFollowSession._prepare()` | 先加一个内部常量/开发面板开关，默认仍为 14M；**发布前不做静默切换** |
| 5 | 归一化 | `core_alignment` 的 `Normalizer` | 双语模型英文输出的大小写与分词形态需实测后再改映射，见 §7.1 |
| 6 | 许可与说明 | `MODEL_LICENSE.md` §6、发布说明 | 已列 A 档白名单；正式随包前把 sha256 全部回填 |
| 7 | 诊断 | `AppLog` 的 `asr/ready` | 增加 `modelId` 字段，便于诊断包区分模型 |

> `ModelInstaller` 的安装目录按 `spec.id` 分目录、marker 为 `.installed-v1`，新增模型不会覆盖 14M，回退无需重新解包。

---

## 5. 下载与校验流程（本次不执行）

### 5.1 下载

```bash
cd teleprompter
DIR=apps/app/assets/models/zipformer-bilingual-zh-en-int8
REPO=csukuangfj/sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20
mkdir -p "$DIR"
for f in encoder-epoch-99-avg-1.int8.onnx \
         decoder-epoch-99-avg-1.int8.onnx \
         joiner-epoch-99-avg-1.int8.onnx \
         tokens.txt; do
  curl -L --fail --retry 3 -o "$DIR/$f" \
    "https://huggingface.co/$REPO/resolve/main/$f?download=true"
done
```

- 国内网络可用 `hf-mirror.com` 镜像，但**必须**按 §5.2 校验 sha256，镜像只当作传输通道。
- 不下载 fp32 版与 `bpe.model`（无解码用途，白占 356 MB）。

### 5.2 校验

```bash
shasum -a 256 "$DIR"/*
# 与 tool/models.lock.json 的 files[].sha256 逐项比对；不一致立即删除重下
```

已从 HF LFS 元数据取得的 sha256（即 LFS oid，**已查证**）：

| 文件 | sha256 |
|---|---|
| `encoder-epoch-99-avg-1.int8.onnx` | `8fa764187a261844f859d7143ebaa563af5d10adfece4c18a8f414c88cba2a9b` |
| `decoder-epoch-99-avg-1.int8.onnx` | `2e3b5ec371f8899ee6acd829fd753ba45772df57a91bdf37cde3136354e7db7d` |
| `joiner-epoch-99-avg-1.int8.onnx` | `1ed689c5ed19dbaa725d9d191bb4822b5f4855a39e1ffd28cbc1f340d25b2ee0` |
| `tokens.txt` | **待本地计算后回填**（非 LFS 文件，HF 未提供摘要） |

### 5.3 登记与入库规则

1. 权重文件**不入 Git**：`.gitignore` 已有 `assets/models/**/*.onnx`；新增目录的 `tokens.txt` 需补一条忽略规则（如 `assets/models/zipformer-bilingual-zh-en-int8/`），否则 56 KB 词表会混进提交。
2. `tool/models.lock.json` 是唯一清单：下载当天把候选条目 `status` 改为 `ready`，补齐 `files[]` 的 `size`/`sha256`/`sha256Source`，并记录 `downloadedAt`。
3. 安装包构建前跑一次校验脚本（可复用现有 `tool/` 里的脚本风格）：缺文件、大小或 sha256 不符即失败，避免把半截模型打进 A 档。
4. 正式随包前，`MODEL_LICENSE.md` §6 的「再分发结论」保持 `允许（A 档）`，并把许可核验日期更新为下载日。

---

## 6. 切换后的评测计划

### 6.1 口径

一律沿用 [`eval/README.md`](../../teleprompter/eval/README.md) §3 与 [`TESTING.md`](../testing/TESTING.md) §5：

| 指标 | 门禁 |
|---|---|
| 误触发/分钟 | **红线**：< 1 次 / 30 min |
| 跟随命中率（真人集） | ≥ 95% |
| 首字延迟 P95（音频轴） | ≤ 800 ms |
| 抢行 `maxOverAdvance` | 不劣于 14M |
| RTF | 单核 < 0.5（首版目标 < 0.3） |

### 6.2 阶段

**阶段 0：宿主 A/B（无需真机，权重到位即可）**

- 同一 10 段 TTS、同一 `run_eval.dart` 参数，跑 14M 与双语各一遍；
- 输出 `build/eval-report-14m.json` / `build/eval-report-bilingual.json`；
- 重点看 `p0-mix-term-01`、`p0-mix-brand-01`：英文是否出词、大小写形态、`Normalizer` 是否吃掉英文；
- 结论先回答「双语是否真的改善中英混说」，再看中文段是否回退。

**阶段 1：真机 SM8750（`tool/eval_device`，profile 构建）**

- 按 `eval/README.md` §5.3 推送双语模型目录、跑同一 10 段；
- 采集 RTF P50/P95、PSS、CPU、冷/热启动加载时间；
- 与 14M 同机对照，按 §6.1 门禁逐项判定。

**阶段 2：60 段真人集补齐后全量回归**

- 中文 / 方言 / 混读 / 口误 / 跳读 / 噪声六类分别报告，不用单一均值掩盖回退；
- 若混读段 CER 相对下降 ≥ 30%、中文段 CER 回退 ≤ 10%（相对）、且红线与延迟门禁通过，才进入正式替换评审。

### 6.3 观感 A/B（同机快速对照）

实验面板已接入（设置 → 实验（开发）→ 语音实验配置），端点与采集参数可在同一台设备上即时切换；模型切换本身计划用「保留 14M + 开发开关」实现，两者配合即可做同稿同人对照。诊断包 header 的 `asrLab` 会记录当次实验配置，便于把主观记录与参数对齐。

---

## 7. 风险与回退

### 7.1 已知风险

| # | 风险 | 影响 | 处置 |
|---|---|---|---|
| R1 | 英文输出大小写/分词与 `Normalizer` 不一致 | 中英混说段反而漏跟 | 阶段 0 先测实际输出；必要时在归一化层做大小写折叠（只改归一化，不回滚模型） |
| R2 | 真机 RTF/首字延迟超预期 | 跟随变慢，违背 D3 | RTF > 0.3 或首字 P95 > 800 ms 时不替换 |
| R3 | 首次解包 198 MB 过慢 | 首启体验差 | 测量后决定是否需要进度提示或改用预解包目录；不得静默卡住 |
| R4 | APK 体积 +200 MB | 分发与安装门槛 | 发布说明明示；若不可接受，回退到「14M + 英文缩写归一化」的过渡方案 |
| R5 | 内存与录制/对齐叠加 | 低端机 OOM | 目标机 12 GB 无虞；若后续支持低内存机型需单列 |
| R6 | 许可变更或再分发争议 | A 档合规 | 已查证 Apache-2.0（模型卡 front matter）；每次换版本重新核验并回填 `models.lock.json` |

### 7.2 回退

- 保留 `AsrModelSpec.zh14mInt8` 与 assets 目录不动，切换只改选择常量/开关；
- 两个模型的安装目录互不覆盖，回退不需要重新解包；
- 回退后清掉双语目录可释放 ≈ 198 MB，但需重新下载才能再切，故评测期建议保留。

---

## 8. 待办清单（决策前）

- [ ] 真机 SM8750 的 14M 基线数据（RTF / PSS / 首字延迟）——等「USB 安装」环境；
- [ ] 用户确认是否接受 +200 MB 包体（这是 A 档的硬门槛）；
- [ ] 下载权重、回填 `tokens.txt` sha256、把 `models.lock.json` 条目标为 `ready`；
- [ ] 阶段 0 宿主 A/B，先回答英文输出与归一化问题；
- [ ] 阶段 1 真机门禁判定；
- [ ] 正式替换评审（含发布说明与许可日期更新）。

---

## 9. 缺陷登记（2026-11-10，单独修，不夹进本轮门禁）

### D1 拉丁术语合并误伤对齐

- **现象**：`p0-mix-term-01` 的台本首行含 `sherpa-onnx`，术语合并把它收成单 token，改变了 ScriptIndex 的 token 偏移；结果 `line_step` 在首行尾部提前触发。
- **证据**：合并关 line1 延迟 779 ms（7460 ms 才正常跳行）；合并开在 5220 ms 就跳到 line1（该行语音 6681 ms 才开始），6500 ms 落到 char23，直到 12580 ms 才补事件 → 计入 5899 ms。
- **影响**：该段跟随均值 841.8→1865.8 ms，最大 2220→5899 ms；全集跟随 P95 2220→5414 ms（n=39 时 P95=第 3 大，单点极值即可推动）。
- **预期**：合并只应在 ASR 输出确实把术语拆成多个拉丁词时生效，不应改变台本索引已有的 token 划分。
- **修复**：`Normalizer` 新增 `mergeLatinTerms`；`ScriptIndex.build` 固定用 `mergeLatinTerms: false`（台本不合并），识别流与 CER 仍合并。台本 `sherpa-onnx` 保持 `sherpa`+`onnx` 两个 token，行边界与合并前完全一致。
- **状态**：已修（2026-11-10）。同一 14M 10 段回归：`mix_term` 的 line1 事件回到 7460 ms（相对 6681 ms = **779 ms**），该段跟随均值 1865.8→841.8 ms、P95 5899→2220 ms，其余 9 段 CER/命中/首字/跟随逐项不变；`core_alignment` 新增 D1 用例（台本偏移 + 候选行不跨行）。

### D2 提前跳行后卡在行尾

- **现象**：一旦提前 `line_step` 到下一行，锚点直接落在 char23（行尾附近），之后整行语音期间不再推进，直到行末才补一次事件。
- **影响**：视觉上提前约 1.5 s 滚到下一行，随后长时间无跟随；命中率与 CER 均不受影响，属于纯时序缺陷。
- **预期**：跳行前提是候选行证据足够强；落点不应贴行尾，跳行后应按新行重建推进。
- **根因**：DP 把「最后一个对齐 token」当作锚点，即使该 token 是未命中的替换；识别尾字被硬对齐到行尾 token 时，阅读锚点即被钉死。
- **修复**：锚点只取路径上**真正命中**（fuzzy 相等）的最后一个 token；未命中的替换/插入/删除不再推进锚点。
- **状态**：已修（2026-11-10）。新增 `tool/eval/test/follow_sim_test.dart` 覆盖「段尾替换不钉行尾」与「提前跨行后仍能推进并进入下一行」；10 段回归命中率 94.9% 不变、误触发 0，跟随 P50 780→880 ms（两段各滞后约一个更新，属换取不再卡行的代价）。


---

## 10. 0.23.0 接入记录（2026-11-10）

**决策**：语音跟随默认 `zipformer-bilingual-mixed`；14M 保留为设置项「识别模型 → 中文轻量」，旧预设缺省按混合模型加载，不迁移或清除用户数据。

**同机对照（Xiaomi 24091RPADC / SM8635 / Android 16，同一 harness、同一会话，0.5 s 采样）**

| 指标 | 14M | 中英混合 | 差值 |
|---|---|---|---|
| 首段加载 loadMs（进程冷启动） | 746.7 | 1320.4 | +573.7 ms（+76.8%） |
| 后续段加载（中位） | 661 | 1225 | +564 ms |
| PSS 峰值（10 段全程） | 387.4 MB | 550.2 MB | +162.8 MB |
| 10 段 CER | 11.6% | 3.5% | -8.1 pp |
| 命中率 | 94.9% | 94.9% | 0 |
| 首字 P50/P95 | 460/780 ms | 460/712 ms | P95 -68 ms |
| 跟随 P50/P95 | 880/2220 ms | 780/3417 ms | — |
| RTF | 0.0234 | 0.0675 | +0.0441 |
| 误触发 | 0 | 0 | 0 |

说明：

- 上表 PSS 是 harness 进程级 TOTAL PSS，绝对值高于产品（历史 14M 产品基线 164–168 MB），只用于同 harness 差值；产品级 PSS 需在 0.23.0 安装后复测。
- 加载差为冷/热两组实测；非 root 设备无法清空 page cache，「冷启动」指进程冷启动，不是磁盘冷读。
- 混合精度宿主管线在 D1/D2 修复后：CER 3.4%、命中 94.9%、首字 P95 712 ms、跟随 P50/P95 780/3417 ms、RTF 0.1005（`build/d1d2-after-mixed.json`）；修复前为命中 89.7%、跟随 P95 5414 ms。
- 覆盖率：`core_alignment` 93.5%（375/401 行，要求 ≥85%）；`apps/app` 的 `flutter test` 在本机被 x64 Flutter SDK + arm64-only CLT 的原生资源构建阻断（pdfium_dart hook 需要完整 Xcode），未取得 app 覆盖率，属本机工具链限制。
