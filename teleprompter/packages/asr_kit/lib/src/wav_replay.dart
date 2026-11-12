import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// 解析后的 16-bit PCM WAV。
class PcmWav {
  const PcmWav({
    required this.sampleRate,
    required this.channels,
    required this.samples,
  });

  final int sampleRate;
  final int channels;
  final Float32List samples;

  double get durationSeconds => samples.length / channels / sampleRate;

  static Future<PcmWav> fromAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return parse(data.buffer.asUint8List());
  }

  /// 只支持 PCM16（M0 测试素材均为 sherpa-onnx 发布的 16k 单声道 wav）。
  static PcmWav parse(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    var offset = 12; // RIFF header
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
        if (audioFormat != 1) {
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

    return PcmWav(
      sampleRate: sampleRate,
      channels: channels,
      samples: samples,
    );
  }
}

/// 用固定 32 ms 分片实时回放 WAV，用于无麦克风环境的确定性联调。
class WavReplaySource {
  WavReplaySource(this.wav, {this.chunkMs = 32});

  final PcmWav wav;
  final int chunkMs;

  Stream<Float32List> play() {
    late StreamController<Float32List> controller;
    Timer? timer;
    var offset = 0;
    final chunk = (wav.sampleRate * chunkMs / 1000).round();

    void tick() {
      if (offset >= wav.samples.length) {
        timer?.cancel();
        controller.close();
        return;
      }
      final end = (offset + chunk).clamp(0, wav.samples.length);
      controller.add(wav.samples.sublist(offset, end));
      offset = end;
    }

    controller = StreamController<Float32List>(
      onListen: () {
        tick();
        timer = Timer.periodic(Duration(milliseconds: chunkMs), (_) => tick());
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }
}
