/// 英文/拉丁术语表：用于把 ASR 拆散的英文词还原成单个 token。
///
/// 背景：双语模型输出大写 BPE 片段，品牌名/技术术语经常被拆成多个词
/// （`I PHONE`、`WII FI`、`SHERPA ONNX`），而台本写的是 `iPhone`、`Wi-Fi`、
/// `sherpa-onnx`。按 token 计 CER 时，这种拆分会被算成多次替换+插入，
/// 与识别质量无关，需要在归一化层对齐。
///
/// 维护规则：
/// 1. 只登记「会被拆开且必须视为一个整体」的术语，普通英文单词不要加；
/// 2. 全部小写，不含连字符/空格（`sherpa-onnx` 写作 `sherpaonnx`）；
/// 3. 匹配时对重复字母折叠（`wii fi` → `wifi`），因此表里无需登记错拼变体；
/// 4. 新增术语请同时补 `test/normalizer_test.dart` 的回归用例。
const List<String> latinTerms = [
  // 品牌 / 产品
  'iphone', 'ipad', 'ipod', 'macbook', 'macos', 'ios', 'android',
  'wifi', 'bluetooth', 'github', 'gitlab', 'openai', 'chatgpt', 'copilot',
  'flutter', 'dart', 'python', 'kotlin', 'swift', 'javascript', 'typescript',
  'nodejs', 'react', 'vue', 'docker', 'kubernetes', 'linux', 'ubuntu',
  'chrome', 'safari', 'firefox', 'wechat', 'alipay', 'tiktok', 'youtube',
  'bilibili', 'google', 'apple', 'microsoft', 'amazon', 'nvidia',
  'qualcomm', 'snapdragon', 'dimensity', 'xiaomi', 'huawei', 'honor',
  'oppo', 'vivo', 'oneplus', 'redmi', 'samsung', 'pixel',
  // 技术术语 / 协议 / 文件格式
  'api', 'sdk', 'json', 'xml', 'html', 'css', 'sql', 'http', 'https',
  'url', 'uri', 'dns', 'vpn', 'usb', 'cpu', 'gpu', 'npu', 'ram', 'rom',
  'ssd', 'hdd', 'pdf', 'csv', 'ui', 'ux', 'ai', 'ml', 'nlp', 'asr', 'tts',
  'ocr', 'onnx', 'sherpaonnx', 'sso', 'jwt', 'oauth', 'grpc', 'websocket',
  'webrtc', 'ffmpeg', 'tensorflow', 'pytorch', 'numpy', 'pandas', 'redis',
  'mysql', 'postgresql', 'mongodb', 'kafka', 'nginx', 'springboot',
];
