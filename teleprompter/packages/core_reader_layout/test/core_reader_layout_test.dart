import 'package:core_reader_layout/core_reader_layout.dart';
import 'package:test/test.dart';

/// 固定宽度切行的假测量器：每 [chunk] 个字符一个视觉行。
class FakeMeasurer implements RowMeasurer {
  FakeMeasurer({this.chunk = 4, this.height = 40});

  final int chunk;
  final double height;

  @override
  List<MeasuredRow> measure(String text, {required double maxWidth}) {
    if (text.isEmpty) {
      return [MeasuredRow(charStart: 0, charEnd: 0, text: '', height: height)];
    }
    final rows = <MeasuredRow>[];
    var start = 0;
    while (start < text.length) {
      final end = (start + chunk).clamp(0, text.length);
      rows.add(
        MeasuredRow(
          charStart: start,
          charEnd: end,
          text: text.substring(start, end),
          height: height,
        ),
      );
      start = end;
    }
    return rows;
  }
}

void main() {
  group('LayoutSnapshot', () {
    test('单行文本生成一个视觉行并建立映射', () {
      final snapshot = LayoutSnapshot.build(
        lines: const ['一二三四', '五六七八'],
        measurer: FakeMeasurer(),
        maxWidth: 200,
        rowPadY: 5,
        rowGap: 10,
      );

      expect(snapshot.rowCount, 2);
      expect(snapshot.lineCount, 2);
      expect(snapshot.rowHeight, 50);
      expect(snapshot.pitch, 60);
      expect(snapshot.rowForLine(0), 0);
      expect(snapshot.rowForLine(1), 1);
      expect(snapshot.lineOfRow(1), 1);
      expect(snapshot.targetForRow(1), 60);
      expect(snapshot.maxScroll, 60);
    });

    test('折行时一个语义行映射到多个视觉行', () {
      final snapshot = LayoutSnapshot.build(
        lines: const ['一二三四五六七八九'],
        measurer: FakeMeasurer(chunk: 4),
        maxWidth: 200,
        rowPadY: 0,
        rowGap: 0,
      );

      expect(snapshot.rowCount, 3);
      expect(snapshot.lineRowCount, [3]);
      expect(snapshot.rowForLine(0), 0);
      expect(snapshot.rowForChar(0, 0), 0);
      expect(snapshot.rowForChar(0, 3), 0);
      expect(snapshot.rowForChar(0, 4), 1);
      expect(snapshot.rowForChar(0, 8), 2);
      expect(snapshot.rowForChar(0, 999), 2);
    });

    test('rowPositionForChar 在行内连续变化，跨行整数递增', () {
      final snapshot = LayoutSnapshot.build(
        lines: const ['一二三四五六七八九'],
        measurer: FakeMeasurer(chunk: 4),
        maxWidth: 200,
        rowPadY: 0,
        rowGap: 0,
      );

      expect(snapshot.rowPositionForChar(0, 0), 0);
      expect(snapshot.rowPositionForChar(0, 2), closeTo(0.5, 1e-9));
      expect(snapshot.rowPositionForChar(0, 4), 1);
      expect(snapshot.rowPositionForChar(0, 6), closeTo(1.5, 1e-9));
      expect(snapshot.rowPositionForChar(0, 8), 2);
      expect(snapshot.rowPositionForChar(0, 999), 3);
    });

    test('空行仍然占一个视觉行', () {
      final snapshot = LayoutSnapshot.build(
        lines: const ['', '正文'],
        measurer: FakeMeasurer(),
        maxWidth: 200,
        rowPadY: 2,
        rowGap: 2,
        fallbackTextHeight: 20,
      );

      expect(snapshot.rowCount, 2);
      expect(snapshot.rows.first.text, '');
      expect(snapshot.rowForLine(1), 1);
    });

    test('测量器返回空结果时使用兜底高度', () {
      final snapshot = LayoutSnapshot.build(
        lines: const ['甲'],
        measurer: _EmptyMeasurer(),
        maxWidth: 200,
        rowPadY: 1,
        rowGap: 3,
        fallbackTextHeight: 30,
      );

      expect(snapshot.rowHeight, 32);
      expect(snapshot.pitch, 35);
      expect(snapshot.rows.single.text, '甲');
    });

    test('rowAtPosition 取最近行并夹取边界', () {
      final snapshot = LayoutSnapshot.build(
        lines: const ['甲', '乙', '丙'],
        measurer: FakeMeasurer(),
        maxWidth: 200,
        rowPadY: 5,
        rowGap: 5,
      );

      expect(snapshot.rowAtPosition(0), 0);
      expect(snapshot.rowAtPosition(27), 0);
      expect(snapshot.rowAtPosition(28), 1);
      expect(snapshot.rowAtPosition(99999), 2);
      expect(snapshot.rowAtPosition(-10), 0);
    });

    test('withTopPad 只改变内容坐标，不改变目标偏移', () {
      final snapshot = LayoutSnapshot.build(
        lines: const ['甲', '乙'],
        measurer: FakeMeasurer(),
        maxWidth: 200,
        rowPadY: 0,
        rowGap: 0,
      );
      final padded = snapshot.withTopPad(120);

      expect(padded.rows.first.top, 120);
      expect(padded.rows.last.top, 160);
      expect(padded.targetForRow(1), snapshot.targetForRow(1));
    });
  });

  group('ReadingBand', () {
    ReadingBand band({
      double ratio = 0.34,
      bool mirror = false,
      double prismDy = 0,
    }) {
      return ReadingBand(
        viewportHeight: 800,
        safeTop: 50,
        safeBottom: 700,
        bandRatio: ratio,
        rowHeight: 70,
        rowGap: 10,
        prismDy: prismDy,
      );
    }

    test('带中心按安全区比例并夹取最小上下行数', () {
      final value = band();
      expect(value.bandCenter, closeTo(271, 0.001));
      expect(value.bandTop, closeTo(236, 0.001));
      expect(value.pitch, 80);
      expect(value.rowsVisible, 8);
      expect(value.rowsAbove, 2);
      expect(value.rowsBelow, 5);
    });

    test('比例过低时夹到带上方至少 1 行', () {
      final value = band(ratio: 0.0);
      expect(value.bandCenter, greaterThanOrEqualTo(50 + 80 + 35));
    });

    test('未镜像目标为行号 × 行距', () {
      final value = band();
      expect(value.targetForRow(3), 240);
      expect(value.targetForRowWithMirror(3, mirrorY: false), 240);
    });

    test('垂直镜像目标补偿屏高与带位置', () {
      final value = band(mirror: true, prismDy: 0.02);
      final target = value.targetForRowWithMirror(3, mirrorY: true);
      // row*pitch + 2*bandTop - H - prismDy*H
      expect(target, closeTo(3 * 80 + 2 * 236 - 800 - 16, 0.001));
      final screenTop = value.screenTopForRow(3, target, mirrorY: true);
      expect(screenTop, closeTo(value.bandTop, 0.001));
    });

    test('极端字号下安全区不足以放下最小行数时仍给出可用带中心', () {
      final value = ReadingBand(
        viewportHeight: 200,
        safeTop: 40,
        safeBottom: 52,
        bandRatio: 0.34,
        rowHeight: 70,
        rowGap: 10,
      );
      expect(value.bandCenter, greaterThanOrEqualTo(75));
      expect(value.rowsVisible, greaterThanOrEqualTo(1));
    });
  });

  group('BandEmphasis', () {
    test('带内行最强，相邻行按半径衰减', () {
      expect(BandEmphasis.valueForRow(row: 3, anchorRow: 3), 1);
      expect(
        BandEmphasis.valueForRow(row: 4, anchorRow: 3, radius: 2),
        closeTo(0.5, 0.011),
      );
      expect(BandEmphasis.valueForRow(row: 5, anchorRow: 3), 0);
    });

    test('屏幕几何连续强调', () {
      expect(
        BandEmphasis.valueForScreen(
          screenRowTop: 230,
          rowHeight: 70,
          bandCenter: 265,
          pitch: 80,
        ),
        1,
      );
      expect(
        BandEmphasis.valueForScreen(
          screenRowTop: 310,
          rowHeight: 70,
          bandCenter: 265,
          pitch: 80,
        ),
        lessThan(1),
      );
    });

    test('非法参数回退 0', () {
      expect(
        BandEmphasis.valueForScreen(
          screenRowTop: 0,
          rowHeight: 10,
          bandCenter: 0,
          pitch: 0,
        ),
        0,
      );
    });
  });

  group('ReadingFollower', () {
    test('语音吸附单行：500 ms 内到位，前快后慢且不过冲', () {
      final follower = ReadingFollower()
        ..configureBounds(min: 0, max: 1000, pitch: 100)
        ..snapTo(100);
      expect(follower.snapping, isTrue);
      follower.step(0.25);
      // half time：easeOutCubic 已完成 87.5%，说明是非线性而非匀速
      expect(follower.position, greaterThan(80));
      expect(follower.position, lessThan(100));
      follower.step(0.25);
      expect(follower.position, closeTo(100, 1e-6));
      expect(follower.snapping, isFalse);
      for (var i = 0; i < 3; i++) {
        follower.step(1 / 60);
      }
      expect(follower.atRest, isTrue);
    });

    test('单行事件完成后，下一行事件重新按 500 ms', () {
      final follower = ReadingFollower()
        ..configureBounds(min: 0, max: 1000, pitch: 100)
        ..snapTo(100)
        ..step(0.5);
      expect(follower.position, closeTo(100, 1e-6));
      follower
        ..snapTo(200)
        ..step(0.25);
      expect(follower.position, closeTo(187.5, 1e-6));
      expect(follower.snapping, isTrue);
      follower.step(0.25);
      expect(follower.position, closeTo(200, 1e-6));
    });

    test('吸附中重复同一目标不重启动画', () {
      final follower = ReadingFollower()
        ..configureBounds(min: 0, max: 1000, pitch: 100)
        ..snapTo(100);
      follower.step(0.48);
      follower.snapTo(100);
      follower
        ..step(0.02)
        ..step(0.02);
      expect(follower.snapping, isFalse);
      expect(follower.position, closeTo(100, 1e-6));
    });

    test('首行 500 ms、追加行 160 ms：跨 3 行共 820 ms', () {
      final follower = ReadingFollower()
        ..configureBounds(min: 0, max: 1000, pitch: 100)
        ..snapTo(300);
      follower.step(0.5);
      // 第一段走满 500 ms，正好落在第 1 行，第二段刚开始
      expect(follower.position, closeTo(100, 1e-6));
      expect(follower.snapSegments, 2);
      follower.step(0.16);
      expect(follower.position, closeTo(200, 1e-6));
      follower.step(0.16);
      expect(follower.position, closeTo(300, 1e-6));
      expect(follower.snapping, isFalse);
    });

    test('跨 3 行分 3 段逐行吸附，每段不超过 1 行', () {
      final follower = ReadingFollower()
        ..configureBounds(min: 0, max: 1000, pitch: 100)
        ..snapTo(300);
      var previous = follower.position;
      for (var i = 0; i < 52; i++) {
        follower.step(1 / 60);
        expect((follower.position - previous).abs(), lessThanOrEqualTo(100));
        previous = follower.position;
      }
      expect(follower.position, closeTo(300, 1e-6));
      expect(follower.snapping, isFalse);
    });

    test('超过 8 行直接落位并淡入', () {
      final follower = ReadingFollower()
        ..configureBounds(min: 0, max: 5000, pitch: 100)
        ..snapTo(1900);
      expect(follower.position, 1900);
      expect(follower.snapping, isFalse);
      expect(follower.fading, isTrue);
      expect(follower.fadeOpacity, lessThan(1));
      for (var i = 0; i < 10; i++) {
        follower.step(1 / 100);
      }
      expect(follower.fadeOpacity, 1);
      expect(follower.fading, isFalse);
    });

    test('冻结立即取消吸附，冻结期间目标被忽略', () {
      final follower = ReadingFollower()
        ..configureBounds(min: 0, max: 1000, pitch: 100)
        ..snapTo(500);
      follower.step(0.02);
      expect(follower.snapping, isTrue);
      follower.freeze();
      expect(follower.snapping, isFalse);
      final frozenAt = follower.position;
      follower.snapTo(500);
      for (var i = 0; i < 30; i++) {
        follower.step(1 / 60);
      }
      expect(follower.snapping, isFalse);
      expect(follower.position, closeTo(frozenAt, 0.001));
    });

    test('拖拽与惯性取消吸附并保留连续像素位置', () {
      final follower = ReadingFollower()
        ..configureBounds(min: 0, max: 1000, pitch: 100)
        ..snapTo(300);
      follower.step(0.02);
      expect(follower.snapping, isTrue);
      final before = follower.position;
      follower.nudge(13.7);
      expect(follower.snapping, isFalse);
      expect(follower.position, closeTo(before + 13.7, 1e-9));
      follower
        ..snapTo(300)
        ..step(0.02);
      expect(follower.snapping, isTrue);
      follower.fling(600);
      expect(follower.snapping, isFalse);
      expect(follower.flinging, isTrue);
      for (var i = 0; i < 30; i++) {
        follower.step(1 / 60);
      }
      expect(follower.snapping, isFalse);
    });

    test('松手惯性按速度连续滑动并自然衰减', () {
      final follower = ReadingFollower()
        ..configureBounds(min: 0, max: 5000, pitch: 100)
        ..fling(1200);
      expect(follower.flinging, isTrue);
      var previous = follower.position;
      for (var i = 0; i < 30; i++) {
        follower.step(1 / 60);
        expect(follower.position, greaterThanOrEqualTo(previous));
        previous = follower.position;
      }
      expect(follower.position, greaterThan(0));
      for (var i = 0; i < 300; i++) {
        follower.step(1 / 60);
      }
      expect(follower.flinging, isFalse);
    });

    test('惯性触边即停，不越界', () {
      final follower = ReadingFollower()
        ..configureBounds(min: 0, max: 100, pitch: 100)
        ..fling(3000);
      for (var i = 0; i < 120; i++) {
        follower.step(1 / 60);
      }
      expect(follower.position, 100);
      expect(follower.flinging, isFalse);
    });

    test('冻结后停在当前位置，解冻后重新吸附到位', () {
      final follower = ReadingFollower()
        ..configureBounds(min: 0, max: 1000, pitch: 100)
        ..jumpTo(500);
      follower.step(1 / 60);
      follower.freeze();
      final frozenAt = follower.position;
      for (var i = 0; i < 30; i++) {
        follower.step(1 / 60);
      }
      expect(follower.position, closeTo(frozenAt, 0.001));
      follower
        ..unfreeze()
        ..snapTo(200);
      for (var i = 0; i < 200; i++) {
        follower.step(1 / 60);
      }
      expect(follower.position, closeTo(200, 1e-6));
    });

    test('拖拽直接改位置并接管目标', () {
      final follower = ReadingFollower()
        ..configureBounds(min: 0, max: 1000, pitch: 100)
        ..nudge(250);
      expect(follower.position, 250);
      expect(follower.target, 250);
      follower.nudge(-400);
      expect(follower.position, 0);
    });

    test('手动滚动按行/秒推进并受边界限制', () {
      final follower = ReadingFollower()
        ..configureBounds(min: 0, max: 300, pitch: 100);
      follower.advanceManual(1.0, linesPerSecond: 2);
      expect(follower.position, closeTo(200, 1e-6));
      follower.advanceManual(10, linesPerSecond: 2);
      expect(follower.position, 300);
    });

    test('跳转淡入后位置立即到位', () {
      final follower = ReadingFollower()
        ..configureBounds(min: 0, max: 1000, pitch: 100)
        ..jumpToWithFade(700);
      expect(follower.position, 700);
      expect(follower.fading, isTrue);
    });

    test('平滑度映射吸附时长', () {
      expect(ReadingFollower.snapDurationFromSmoothness(4).inMilliseconds, 550);
      expect(ReadingFollower.snapDurationFromSmoothness(8).inMilliseconds, 500);
      expect(
          ReadingFollower.snapDurationFromSmoothness(12).inMilliseconds, 450);
    });
  });
}

class _EmptyMeasurer implements RowMeasurer {
  @override
  List<MeasuredRow> measure(String text, {required double maxWidth}) =>
      const [];
}
