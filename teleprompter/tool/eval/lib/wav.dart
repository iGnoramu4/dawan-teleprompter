import 'dart:typed_data';

/// 解析后的 16-bit PCM WAV。
class WavData {
  const WavData({
    required this.sampleRate,
    required this.channels,
    required this.samples,
  });

  final int sampleRate;
  final int channels;

  /// 交错排列的浮点采样（-1..1）。
  final Float32List samples;

  int get frameCount => channels == 0 ? 0 : samples.length ~/ channels;

  double get durationMs => frameCount * 1000 / sampleRate;

  /// 取单声道（多声道取平均）。
  Float32List mono() {
    if (channels == 1) return samples;
    final out = Float32List(frameCount);
    for (var i = 0; i < out.length; i++) {
      var sum = 0.0;
      for (var c = 0; c < channels; c++) {
        sum += samples[i * channels + c];
      }
      out[i] = sum / channels;
    }
    return out;
  }
}

/// 线性重采样（评测工具够用；产品链路不做重采样）。
Float32List resample(Float32List input, int from, int to) {
  if (from == to) return input;
  final outLength = (input.length * to / from).round();
  final out = Float32List(outLength);
  final ratio = from / to;
  for (var i = 0; i < outLength; i++) {
    final pos = i * ratio;
    final i0 = pos.floor();
    final i1 = i0 + 1 < input.length ? i0 + 1 : i0;
    final frac = pos - i0;
    out[i] = input[i0] * (1 - frac) + input[i1] * frac;
  }
  return out;
}

/// 解析 PCM16 WAV；只支持 16-bit，多声道会保留原样。
WavData parseWav(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var offset = 12; // RIFF + size + WAVE
  int? sampleRate;
  int? channels;
  int? bits;
  int? dataOffset;
  int? dataLength;

  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    offset += 8;
    if (id == 'fmt ') {
      final audioFormat = data.getUint16(offset, Endian.little);
      if (audioFormat != 1 && audioFormat != 0xFFFE) {
        throw UnsupportedError('仅支持 PCM WAV，实际 format=$audioFormat');
      }
      channels = data.getUint16(offset + 2, Endian.little);
      sampleRate = data.getUint32(offset + 4, Endian.little);
      bits = data.getUint16(offset + 14, Endian.little);
    } else if (id == 'data') {
      dataOffset = offset;
      dataLength = size;
    }
    offset += size + (size.isOdd ? 1 : 0);
  }

  if (sampleRate == null || channels == null || dataOffset == null) {
    throw const FormatException('WAV 缺少 fmt/data 块');
  }
  if (bits != 16) {
    throw UnsupportedError('仅支持 16-bit PCM，实际 bits=$bits');
  }

  final available = bytes.length - dataOffset;
  final length =
      (dataLength == null || dataLength > available) ? available : dataLength;
  final count = length ~/ 2;
  final samples = Float32List(count);
  for (var i = 0; i < count; i++) {
    samples[i] = data.getInt16(dataOffset + i * 2, Endian.little) / 32768.0;
  }
  return WavData(
    sampleRate: sampleRate,
    channels: channels,
    samples: samples,
  );
}

/// 编码为 16-bit PCM 单声道 WAV。
Uint8List encodeWav(Float32List samples, {int sampleRate = 16000}) {
  final byteLength = samples.length * 2;
  final bytes = Uint8List(44 + byteLength);
  final data = ByteData.sublistView(bytes);
  void writeId(int at, String id) {
    for (var i = 0; i < 4; i++) {
      bytes[at + i] = id.codeUnitAt(i);
    }
  }

  writeId(0, 'RIFF');
  data.setUint32(4, 36 + byteLength, Endian.little);
  writeId(8, 'WAVE');
  writeId(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  writeId(36, 'data');
  data.setUint32(40, byteLength, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(44 + i * 2, v, Endian.little);
  }
  return bytes;
}
