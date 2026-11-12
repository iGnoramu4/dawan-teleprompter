/// 录制时长/文件大小的展示格式。
String formatRecordingDuration(int milliseconds) {
  final total = milliseconds < 0 ? 0 : milliseconds;
  final hours = total ~/ 3600000;
  final minutes = (total ~/ 60000) % 60;
  final seconds = (total ~/ 1000) % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:${two(minutes)}:${two(seconds)}';
  return '${two(minutes)}:${two(seconds)}';
}

String formatRecordingSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
