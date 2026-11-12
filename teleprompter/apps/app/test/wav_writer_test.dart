import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/shared/recording/wav_writer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('tps-wav-');
  });

  tearDown(() async {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('写入 Float32 后生成合法 RIFF/WAVE 头与数据长度', () async {
    final path = '${dir.path}/a.wav';
    final writer = await PcmWavWriter.create(path);
    expect(writer.dataBytes, 0);

    await writer.write(Float32List.fromList([0.0, 1.0, -1.0, 2.0, -2.0]));
    expect(writer.dataBytes, 10);

    final file = await writer.close();
    final bytes = await file.readAsBytes();
    final header = ByteData.sublistView(bytes);

    expect(bytes.length, 44 + 10);
    expect(header.getUint32(0, Endian.little), 46); // 36 + data
    expect(header.getUint32(4, Endian.little), 0x57415645);
    expect(header.getUint16(16, Endian.little), 1);
    expect(header.getUint16(18, Endian.little), 1);
    expect(header.getUint32(20, Endian.little), 16000);
    expect(header.getUint32(24, Endian.little), 32000);
    expect(header.getUint32(32, Endian.little), 0x64617461);
    expect(header.getUint32(36, Endian.little), 10);

    expect(header.getInt16(44, Endian.little), 0);
    expect(header.getInt16(46, Endian.little), 32767);
    expect(header.getInt16(48, Endian.little), -32767);
    expect(header.getInt16(50, Endian.little), 32767); // 裁剪
    expect(header.getInt16(52, Endian.little), -32767);
  });

  test('空分片不改变长度，重复 close 幂等', () async {
    final writer = await PcmWavWriter.create('${dir.path}/b.wav');
    await writer.write(Float32List(0));
    expect(writer.dataBytes, 0);
    final first = await writer.close();
    final second = await writer.close();
    expect(second.path, first.path);
    expect((await second.readAsBytes()).length, 44);
  });

  test('abort 删除半成品文件', () async {
    final path = '${dir.path}/c.wav';
    final writer = await PcmWavWriter.create(path);
    await writer.write(Float32List.fromList([0.5]));
    expect(File(path).existsSync(), isTrue);
    await writer.abort();
    expect(File(path).existsSync(), isFalse);
  });
}
