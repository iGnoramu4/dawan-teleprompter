import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core_recording/core_recording.dart';
import 'package:data_store/data_store.dart';
import 'package:file_picker/file_picker.dart';

typedef RecordingFileSaver = Future<bool> Function(
  String fileName,
  Uint8List bytes,
);

/// 默认保存器：系统"另存为"对话框（Android 走 SAF）。
///
/// 返回 false 表示用户取消。
Future<bool> saveFileWithPicker(String fileName, Uint8List bytes) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    dialogTitle: fileName,
  );
  return uri != null;
}

/// E8-3：导出 WAV 原文件 + timeline.json + captions.srt。
///
/// [captionLines] 为字幕使用的行文本（整篇连续文本下通常传视觉行）；[captionIndex]
/// 把时间轴的"语义行 + 行内字符"折算成字幕行号。两者都不传时按 [lines] 行级导出。
///
/// 返回实际写入的文件数；用户取消某个保存时停止后续导出。
Future<int> exportRecording({
  required RecordingEntry entry,
  required List<String> lines,
  RecordingTimeline? timeline,
  List<String>? captionLines,
  int Function(int line, int charOffset)? captionIndex,
  RecordingFileSaver saver = saveFileWithPicker,
}) async {
  final source = timeline ?? _timelineOf(entry);
  final base = _baseName(entry);
  var saved = 0;

  final audio = File(entry.path);
  if (audio.existsSync()) {
    if (!await saver('$base.wav', await audio.readAsBytes())) return saved;
    saved += 1;
  }

  if (!await saver(
    '$base.timeline.json',
    Uint8List.fromList(utf8.encode(source.encode())),
  )) {
    return saved;
  }
  saved += 1;

  final srt = const TimelineSrtExporter().build(
    lines: captionLines ?? lines,
    timeline:
        captionIndex == null ? source : _remapTimeline(source, captionIndex),
  );
  if (!await saver(
    '$base.captions.srt',
    Uint8List.fromList(utf8.encode(srt)),
  )) {
    return saved;
  }
  saved += 1;
  return saved;
}

RecordingTimeline _timelineOf(RecordingEntry entry) {
  final json = entry.timelineJson;
  if (json == null) {
    return RecordingTimeline(
      scriptId: entry.scriptId,
      durationMs: entry.durationMs,
      samples: const [],
    );
  }
  return RecordingTimeline.tryDecode(json) ??
      RecordingTimeline(
        scriptId: entry.scriptId,
        durationMs: entry.durationMs,
        samples: const [],
      );
}

String _baseName(RecordingEntry entry) => recordingBaseName(entry);

/// 把"段落 + 段内字符"时间轴折算成字幕行号（仅用于 SRT 生成）。
RecordingTimeline _remapTimeline(
  RecordingTimeline timeline,
  int Function(int line, int charOffset) indexOf,
) {
  return RecordingTimeline(
    scriptId: timeline.scriptId,
    durationMs: timeline.durationMs,
    samples: [
      for (final sample in timeline.samples)
        TimelineSample(
          t: sample.t,
          anchor: indexOf(sample.anchor, sample.char),
          conf: sample.conf,
        ),
    ],
  );
}

/// 导出文件名（本地时区）：`tps-YYYYMMDD-HHMMSS`。
String recordingBaseName(RecordingEntry entry) {
  final stamp = DateTime.fromMillisecondsSinceEpoch(entry.createdAt);
  String two(int value) => value.toString().padLeft(2, '0');
  return 'tps-${stamp.year}${two(stamp.month)}${two(stamp.day)}-'
      '${two(stamp.hour)}${two(stamp.minute)}${two(stamp.second)}';
}
