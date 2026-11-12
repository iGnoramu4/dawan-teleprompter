import 'package:core_models/core_models.dart';

/// 应用路由表：feature 之间只通过命名路由跳转，避免横向 import。
abstract final class AppRoutes {
  static const String home = '/';
  static const String importPreview = '/import';
  static const String editor = '/editor';
  static const String reader = '/reader';
  static const String settings = '/settings';
  static const String remote = '/remote';
}

/// 导入预览参数。
class ImportArgs {
  const ImportArgs({
    required this.rawText,
    this.sourceLabel,
    this.stripMarkdown = false,
  });

  final String rawText;

  /// 来源标签（文件名/“剪贴板”），为空时用通用“导入”文案。
  final String? sourceLabel;
  final bool stripMarkdown;
}

/// 编辑器参数。
class EditorArgs {
  const EditorArgs(this.scriptId);

  final String scriptId;
}

/// 提词页参数。
class ReaderArgs {
  const ReaderArgs({
    required this.document,
    this.initialAnchor = 0,
    this.initialAnchorModel = 2,
  });

  final ScriptDocument document;
  final int initialAnchor;

  /// 断点锚点的语义行模型：2 = 整篇连续文本（当前唯一模型）。
  final int initialAnchorModel;
}
