import 'dart:io';
import 'dart:typed_data';

/// 16 kHz / 单声道 / 16 bit PCM WAV 写入器（E8-1）。
///
/// 先占位 44 字节头，结束（或异常中止）时回填 RIFF/data 长度，避免把整段
/// 音频放在内存里；与语音跟随共用同一条采集流时不会重复打开麦克风。
class PcmWavWriter {
  PcmWavWriter._(this._file, this._raid, this._dataBytes);

  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int bitsPerSample = 16;
  static const int _headerBytes = 44;

  final File _file;
  final RandomAccessFile _raid;
  int _dataBytes;
  bool _closed = false;

  int get dataBytes => _dataBytes;

  String get path => _file.path;

  static Future<PcmWavWriter> create(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final raid = await file.open(mode: FileMode.write);
    await raid.writeFrom(Uint8List(_headerBytes));
    return PcmWavWriter._(file, raid, 0);
  }

  /// 写入归一化 Float32 分片（范围 [-1, 1]，越界会被裁剪）。
  Future<void> write(Float32List samples) async {
    if (_closed || samples.isEmpty) return;
    final bytes = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      final value = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      bytes.setInt16(i * 2, value, Endian.little);
    }
    await _raid.writeFrom(bytes.buffer.asUint8List());
    _dataBytes += samples.length * 2;
  }

  /// 回填头并关闭文件。
  Future<File> close() async {
    if (_closed) return _file;
    _closed = true;
    await _writeHeader();
    await _raid.flush();
    await _raid.close();
    return _file;
  }

  /// 中止录制：删除半成品文件。
  Future<void> abort() async {
    if (!_closed) {
      _closed = true;
      await _raid.close();
    }
    try {
      if (_file.existsSync()) _file.deleteSync();
    } catch (_) {
      // 删除失败不阻断流程。
    }
  }

  Future<void> _writeHeader() async {
    const byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    const blockAlign = channels * bitsPerSample ~/ 8;
    final header = ByteData(_headerBytes)
      ..setUint32(0, _dataBytes + 36, Endian.little) // RIFF chunk size
      ..setUint32(4, 0x57415645, Endian.little) // "WAVE"
      ..setUint32(8, 0x666d7420, Endian.little) // "fmt "
      ..setUint32(12, 16, Endian.little) // fmt chunk size
      ..setUint16(16, 1, Endian.little) // PCM
      ..setUint16(18, channels, Endian.little)
      ..setUint32(20, sampleRate, Endian.little)
      ..setUint32(24, byteRate, Endian.little)
      ..setUint16(28, blockAlign, Endian.little)
      ..setUint16(30, bitsPerSample, Endian.little)
      ..setUint32(32, 0x64617461, Endian.little) // "data"
      ..setUint32(36, _dataBytes, Endian.little);
    await _raid.setPosition(0);
    await _raid.writeFrom(header.buffer.asUint8List());
    await _raid.setPosition(_headerBytes + _dataBytes);
  }
}
