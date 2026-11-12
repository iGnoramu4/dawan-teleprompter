import 'package:core_recording/core_recording.dart';
import 'package:test/test.dart';

void main() {
  group('RecordingTimeline', () {
    test('JSON 往返保留采样与协议字段', () {
      const timeline = RecordingTimeline(
        scriptId: 'script-1',
        durationMs: 2000,
        samples: [
          TimelineSample(t: 0, anchor: 0, char: 3, conf: 0.6),
          TimelineSample(t: 500, anchor: 1),
          TimelineSample(t: 2000, anchor: 3),
        ],
      );

      final decoded = RecordingTimeline.tryDecode(timeline.encode())!;
      expect(decoded.version, RecordingTimeline.formatVersion);
      expect(decoded.scriptId, 'script-1');
      expect(decoded.durationMs, 2000);
      expect(decoded.samples.length, 3);
      expect(decoded.samples[0].char, 3);
      expect(decoded.samples[0].conf, 0.6);
      expect(decoded.samples[2].anchor, 3);
    });

    test('版本不支持或缺少 scriptId 时拒绝解析', () {
      expect(
        RecordingTimeline.tryDecode(
          '{"version":3,"scriptId":"s","durationMs":0,"samples":[]}',
        ),
        isNull,
      );
      expect(
        RecordingTimeline.tryDecode('{"durationMs":0,"samples":[]}'),
        isNull,
      );
      expect(RecordingTimeline.tryDecode('not-json'), isNull);
    });

    test('v1 时间轴仍可读取，字符偏移按 0 处理', () {
      final decoded = RecordingTimeline.tryDecode(
        '{"version":1,"scriptId":"s","durationMs":100,'
        '"samples":[{"t":0,"anchor":2}]}',
      );
      expect(decoded, isNotNull);
      expect(decoded!.version, 1);
      expect(decoded.samples.single.char, 0);
      expect(decoded.positionAt(50).line, 2);
    });

    test('同段内字符偏移线性插值，跨段回落到端点偏移', () {
      const same = RecordingTimeline(
        scriptId: 's',
        durationMs: 1000,
        samples: [
          TimelineSample(t: 0, anchor: 2, char: 0),
          TimelineSample(t: 1000, anchor: 2, char: 20),
        ],
      );
      expect(same.positionAt(500), (line: 2, char: 10));

      const across = RecordingTimeline(
        scriptId: 's',
        durationMs: 1000,
        samples: [
          TimelineSample(t: 0, anchor: 0, char: 8),
          TimelineSample(t: 1000, anchor: 1, char: 4),
        ],
      );
      expect(across.positionAt(100).line, 0);
      expect(across.positionAt(100).char, 8);
      expect(across.positionAt(900).line, 1);
      expect(across.positionAt(900).char, 4);
    });

    test('锚点线性插值并夹到首尾采样', () {
      const timeline = RecordingTimeline(
        scriptId: 's',
        durationMs: 1000,
        samples: [
          TimelineSample(t: 0, anchor: 0),
          TimelineSample(t: 1000, anchor: 10),
        ],
      );

      expect(timeline.anchorAt(-100), 0);
      expect(timeline.anchorAt(0), 0);
      expect(timeline.anchorAt(250), 3); // 2.5 四舍五入
      expect(timeline.anchorAt(500), 5);
      expect(timeline.anchorAt(1000), 10);
      expect(timeline.anchorAt(1500), 10);
    });

    test('空时间轴返回 0，重复时间戳不除零', () {
      const empty = RecordingTimeline(
        scriptId: 's',
        durationMs: 0,
        samples: [],
      );
      expect(empty.anchorAt(100), 0);

      const duplicated = RecordingTimeline(
        scriptId: 's',
        durationMs: 10,
        samples: [
          TimelineSample(t: 5, anchor: 2),
          TimelineSample(t: 5, anchor: 4),
        ],
      );
      expect(duplicated.anchorAt(5), 2);
    });
  });

  group('TimelineBuilder', () {
    test('按 100 ms 间隔采样，过密调用被丢弃', () {
      final builder = TimelineBuilder(scriptId: 's');
      builder
        ..sample(0, 0)
        ..sample(50, 1)
        ..sample(100, 1)
        ..sample(200, 2, conf: 0.8);

      expect(builder.samples.length, 3);
      expect(builder.samples.map((s) => s.t), [0, 100, 200]);
      expect(builder.samples.last.conf, 0.8);
    });

    test('负数时间与行号被归一化，结束时间不早于最后采样', () {
      final builder = TimelineBuilder(scriptId: 's');
      builder.sample(-10, -3);
      expect(builder.samples.single.t, 0);
      expect(builder.samples.single.anchor, 0);

      final timeline = builder.finish(0);
      expect(timeline.durationMs, 0);

      builder.sample(1000, 5);
      expect(builder.finish(500).durationMs, 1000);
    });

    test('自定义采样间隔', () {
      final builder = TimelineBuilder(scriptId: 's', intervalMs: 500);
      builder
        ..sample(0, 0)
        ..sample(200, 1)
        ..sample(500, 1);
      expect(builder.samples.length, 2);
    });
  });

  group('TimelineSrtExporter', () {
    const exporter = TimelineSrtExporter();
    const lines = ['第一行\n带换行', '第二行', '未读到的行'];

    test('按停留行生成 SRT，时间码与文本正确', () {
      const timeline = RecordingTimeline(
        scriptId: 's',
        durationMs: 2000,
        samples: [
          TimelineSample(t: 0, anchor: 0),
          TimelineSample(t: 500, anchor: 0),
          TimelineSample(t: 500, anchor: 1),
          TimelineSample(t: 1200, anchor: 1),
          TimelineSample(t: 2000, anchor: 2),
        ],
      );

      final srt = exporter.build(lines: lines, timeline: timeline);
      expect(
        srt,
        '1\n'
        '00:00:00,000 --> 00:00:00,500\n'
        '第一行 带换行\n\n'
        '2\n'
        '00:00:00,500 --> 00:00:02,000\n'
        '第二行\n\n',
      );
    });

    test('空台本或空时间轴返回空字符串', () {
      const timeline = RecordingTimeline(
        scriptId: 's',
        durationMs: 100,
        samples: [TimelineSample(t: 0, anchor: 0)],
      );
      expect(exporter.build(lines: const [], timeline: timeline), '');
      expect(
        exporter.build(
          lines: lines,
          timeline: const RecordingTimeline(
            scriptId: 's',
            durationMs: 0,
            samples: [],
          ),
        ),
        '',
      );
    });

    test('越界行号与零时长片段被跳过，小时可超过两位', () {
      const timeline = RecordingTimeline(
        scriptId: 's',
        durationMs: 359999999,
        samples: [
          TimelineSample(t: 0, anchor: 5),
          TimelineSample(t: 10, anchor: 99),
          TimelineSample(t: 1000, anchor: 0),
          TimelineSample(t: 359999999, anchor: 0),
        ],
      );
      final srt = exporter.build(lines: const ['结尾'], timeline: timeline);
      expect(srt, contains('99:59:59,999'));
      expect(srt, contains('结尾'));
      expect(srt.split('\n\n').where((block) => block.isNotEmpty).length, 1);
    });
  });
}
