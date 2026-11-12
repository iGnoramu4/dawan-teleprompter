import 'dart:math' as math;

/// 文本测量器产出的一行（单行，不折行）。
///
/// [charStart] / [charEnd] 是相对**语义行**的字符下标，`charEnd` 不含。
class MeasuredRow {
  /// 创建测量行。
  const MeasuredRow({
    required this.charStart,
    required this.charEnd,
    required this.text,
    required this.height,
  });

  /// 行内起始字符下标（含）。
  final int charStart;

  /// 行内结束字符下标（不含）。
  final int charEnd;

  /// 该行实际渲染的文本。
  final String text;

  /// 该行文字盒高度（px，已含 `textScaler`）。
  final double height;
}

/// 与渲染完全一致的文本测量接口。
///
/// 宿主必须使用与 `Text` 相同的字体、字号、字重、字距、`textScaler` 与
/// 对齐方式测量；否则视觉行切分与真实折行会不一致。
abstract interface class RowMeasurer {
  /// 测量 [text] 在 [maxWidth] 下的视觉行。
  List<MeasuredRow> measure(String text, {required double maxWidth});
}

/// 一个实际渲染的视觉行（单行）。
class VisualRow {
  /// 创建视觉行。
  const VisualRow({
    required this.index,
    required this.lineIndex,
    required this.charStart,
    required this.charEnd,
    required this.text,
    required this.height,
    required this.top,
  });

  /// 视觉行序号（0 基，全稿连续）。
  final int index;

  /// 所属语义行号。
  final int lineIndex;

  /// 相对语义行的起始字符下标（含）。
  final int charStart;

  /// 相对语义行的结束字符下标（不含）。
  final int charEnd;

  /// 文本内容。
  final String text;

  /// 行高（px）。
  final double height;

  /// 内容坐标下的行顶（px，含顶部垫）。
  final double top;
}

/// 一份布局快照：视觉行几何 + 语义行/视觉行映射。
///
/// 语义行仍用于语音对齐、断点、遥控与录制；视觉行只用于渲染与滚动。
class LayoutSnapshot {
  LayoutSnapshot._({
    required this.rows,
    required this.lineStartRow,
    required this.lineRowCount,
    required this.rowHeight,
    required this.rowGap,
    required this.topPad,
    required this.textRevision,
    required this.maxWidth,
  });

  /// 所有视觉行。
  final List<VisualRow> rows;

  /// 每个语义行的首个视觉行下标。
  final List<int> lineStartRow;

  /// 每个语义行占用的视觉行数。
  final List<int> lineRowCount;

  /// 统一的视觉行高度（px）。
  final double rowHeight;

  /// 视觉行间距（px）。
  final double rowGap;

  /// 内容顶部垫（= 阅读带 top），使第 0 行行顶对齐阅读带。
  final double topPad;

  /// 文本修订号：文本变化时递增，用于外部缓存失效。
  final int textRevision;

  /// 构建时使用的可用宽度。
  final double maxWidth;

  /// 视觉行行距（px）。
  double get pitch => rowHeight + rowGap;

  /// 视觉行总数。
  int get rowCount => rows.length;

  /// 语义行总数。
  int get lineCount => lineStartRow.length;

  /// 最大滚动偏移：最后一行走到阅读带所需的位置。
  double get maxScroll => rowCount == 0 ? 0 : (rowCount - 1) * pitch;

  /// 构建快照。
  ///
  /// - [lines] 为语义行文本；
  /// - [measurer] 决定折行，必须与真实渲染一致；
  /// - [rowPadY] 为视觉行上下内边距（单侧）；
  /// - [rowGap] 为视觉行间距；
  /// - [fallbackTextHeight] 在测量器返回空结果时兜底。
  factory LayoutSnapshot.build({
    required List<String> lines,
    required RowMeasurer measurer,
    required double maxWidth,
    required double rowPadY,
    required double rowGap,
    double fallbackTextHeight = 16,
    int textRevision = 0,
  }) {
    final safeWidth = math.max(1.0, maxWidth);
    final safePad = math.max(0.0, rowPadY);
    final safeGap = math.max(0.0, rowGap);

    final measuredPerLine = <List<MeasuredRow>>[];
    var maxTextHeight = math.max(1.0, fallbackTextHeight);
    for (final line in lines) {
      var rows = measurer.measure(line, maxWidth: safeWidth);
      rows = rows.where((row) => row.height > 0).toList(growable: false);
      if (rows.isEmpty) {
        rows = [
          MeasuredRow(
            charStart: 0,
            charEnd: line.length,
            text: line,
            height: math.max(1.0, fallbackTextHeight),
          ),
        ];
      }
      for (final row in rows) {
        maxTextHeight = math.max(maxTextHeight, row.height);
      }
      measuredPerLine.add(rows);
    }

    final rowHeight = maxTextHeight + safePad * 2;
    final pitch = rowHeight + safeGap;
    final rows = <VisualRow>[];
    final lineStartRow = <int>[];
    final lineRowCount = <int>[];

    for (var line = 0; line < measuredPerLine.length; line++) {
      final measured = measuredPerLine[line];
      lineStartRow.add(rows.length);
      lineRowCount.add(measured.length);
      for (final row in measured) {
        final index = rows.length;
        rows.add(
          VisualRow(
            index: index,
            lineIndex: line,
            charStart: row.charStart,
            charEnd: row.charEnd,
            text: row.text,
            height: rowHeight,
            top: index * pitch,
          ),
        );
      }
    }

    return LayoutSnapshot._(
      rows: rows,
      lineStartRow: lineStartRow,
      lineRowCount: lineRowCount,
      rowHeight: rowHeight,
      rowGap: safeGap,
      topPad: 0,
      textRevision: textRevision,
      maxWidth: safeWidth,
    );
  }

  /// 语义行 → 首个视觉行。
  int rowForLine(int line) {
    if (lineStartRow.isEmpty) return 0;
    final clamped = line.clamp(0, lineStartRow.length - 1);
    return lineStartRow[clamped];
  }

  /// 语义行 + 行内字符偏移 → 视觉行。
  int rowForChar(int line, int charOffset) {
    if (lineStartRow.isEmpty) return 0;
    final clampedLine = line.clamp(0, lineStartRow.length - 1);
    final start = lineStartRow[clampedLine];
    final count = lineRowCount[clampedLine];
    if (count <= 1) return start;
    final offset = math.max(0, charOffset);
    for (var i = 0; i < count; i++) {
      final row = rows[start + i];
      if (offset < row.charEnd) return start + i;
    }
    return start + count - 1;
  }

  /// 语义行 + 行内字符偏移 → 连续行位置（整数行为行号，小数部分为本行进度）。
  ///
  /// 跟随目标用这个值乘以行距，即可在行内连续推进，
  /// 而不是等字符跨过行边界才整行移动。
  double rowPositionForChar(int line, int charOffset) {
    if (rows.isEmpty) return 0;
    final row = rowForChar(line, charOffset);
    final current = rows[row];
    final span = math.max(1, current.charEnd - current.charStart);
    final progress =
        ((charOffset - current.charStart) / span).clamp(0.0, 1.0).toDouble();
    return row + progress;
  }

  /// 视觉行 → 语义行。
  int lineOfRow(int row) {
    if (rows.isEmpty) return 0;
    return rows[row.clamp(0, rows.length - 1)].lineIndex;
  }

  /// 内容坐标 → 最近的视觉行。
  int rowAtPosition(double position) {
    if (rows.isEmpty) return 0;
    final index = (position / pitch).round();
    return index.clamp(0, rows.length - 1);
  }

  /// 某个视觉行走进阅读带所需的内容滚动偏移。
  double targetForRow(int row) {
    if (rows.isEmpty) return 0;
    return row.clamp(0, rows.length - 1) * pitch;
  }

  /// 以指定锚点重建顶部垫（阅读带位置）。
  ///
  /// 快照本身不持有视口信息；渲染前由 [withTopPad] 写入带 top，
  /// 使 `VisualRow.top` 与内容坐标一致。
  LayoutSnapshot withTopPad(double topPad) {
    return LayoutSnapshot._(
      rows: [
        for (final row in rows)
          VisualRow(
            index: row.index,
            lineIndex: row.lineIndex,
            charStart: row.charStart,
            charEnd: row.charEnd,
            text: row.text,
            height: row.height,
            top: topPad + row.index * pitch,
          ),
      ],
      lineStartRow: lineStartRow,
      lineRowCount: lineRowCount,
      rowHeight: rowHeight,
      rowGap: rowGap,
      topPad: topPad,
      textRevision: textRevision,
      maxWidth: maxWidth,
    );
  }
}
