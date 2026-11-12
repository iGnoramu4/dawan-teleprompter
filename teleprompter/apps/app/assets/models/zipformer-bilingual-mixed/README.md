# 模型权重占位目录

本目录不包含模型权重。构建前请按 `teleprompter/tool/models.lock.json` 中的 `files` 清单获取并校验文件，放置于本目录：

- `encoder-epoch-99-avg-1.int8.onnx`
- `decoder-epoch-99-avg-1.onnx`
- `joiner-epoch-99-avg-1.onnx`
- `tokens.txt`

注意：本模型使用 int8 encoder + fp32 decoder/joiner，decoder/joiner 文件名不带 `.int8` 后缀。来源、体积、SHA256 与许可边界见 `models.lock.json` 与仓库根目录 `MODEL_LICENSE.md`。
