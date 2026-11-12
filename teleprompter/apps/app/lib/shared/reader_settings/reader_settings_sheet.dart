import 'package:core_alignment/core_alignment.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'overlay_settings.dart';
import 'reader_settings.dart';

/// 打开阅读设置面板（§4.4 排版 + §4.3 滚动/跟随参数，即时生效）。
Future<void> showReaderSettingsSheet({
  required BuildContext context,
  required ReaderSettings settings,
  required ValueChanged<ReaderSettings> onChanged,
  ValueChanged<ReaderSettings>? onSaveAsDefault,
  OverlaySettings? overlaySettings,
  ValueChanged<OverlaySettings>? onOverlayChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Theme(
      data: TpTheme.dark(),
      child: _ReaderSettingsSheet(
        settings: settings,
        onChanged: onChanged,
        onSaveAsDefault: onSaveAsDefault,
        overlaySettings: overlaySettings,
        onOverlayChanged: onOverlayChanged,
      ),
    ),
  );
}

class _ReaderSettingsSheet extends StatefulWidget {
  const _ReaderSettingsSheet({
    required this.settings,
    required this.onChanged,
    this.onSaveAsDefault,
    this.overlaySettings,
    this.onOverlayChanged,
  });

  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  /// 保存为全局默认参数（M1-c）。
  final ValueChanged<ReaderSettings>? onSaveAsDefault;

  /// 悬浮窗样式（W-03），仅阅读页传入。
  final OverlaySettings? overlaySettings;
  final ValueChanged<OverlaySettings>? onOverlayChanged;

  @override
  State<_ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<_ReaderSettingsSheet> {
  late ReaderSettings _settings = widget.settings;
  late OverlaySettings _overlay =
      widget.overlaySettings ?? OverlaySettings.defaults;

  void _update(ReaderSettings next) {
    setState(() => _settings = next.normalized());
    widget.onChanged(_settings);
  }

  void _patch(ReaderSettings Function(ReaderSettings) builder) {
    _update(builder(_settings));
  }

  void _patchOverlay(OverlaySettings Function(OverlaySettings) builder) {
    setState(() => _overlay = builder(_overlay).normalized());
    widget.onOverlayChanged?.call(_overlay);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final height = MediaQuery.sizeOf(context).height;
    return SizedBox(
      height: height * 0.86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TpTokens.space4,
              0,
              TpTokens.space2,
              TpTokens.space1,
            ),
            child: Row(
              children: [
                Text(l10n.sheetTitle,
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (widget.onSaveAsDefault != null)
                  TextButton(
                    onPressed: () => widget.onSaveAsDefault!(_settings),
                    child: Text(l10n.sheetSaveAsDefault),
                  ),
                TextButton(
                  onPressed: () => _update(ReaderSettings.defaults),
                  child: Text(l10n.sheetRestoreDefaults),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                TpTokens.space4,
                TpTokens.space2,
                TpTokens.space4,
                TpTokens.space8,
              ),
              children: [
                _sectionTitle(context, l10n.sheetSectionVisual),
                SegmentedButton<ReaderTheme>(
                  segments: [
                    ButtonSegment(
                      value: ReaderTheme.stageDark,
                      label: Text(l10n.readerThemeDark),
                      icon: const Icon(Icons.dark_mode_outlined),
                    ),
                    ButtonSegment(
                      value: ReaderTheme.stageWhite,
                      label: Text(l10n.readerThemeWhite),
                      icon: const Icon(Icons.light_mode_outlined),
                    ),
                  ],
                  selected: {_settings.theme},
                  onSelectionChanged: (selection) =>
                      _patch((s) => s.copyWith(theme: selection.first)),
                ),
                _SliderTile(
                  label: l10n.sheetFontSize,
                  value: _settings.fontSize,
                  min: 24,
                  max: 160,
                  divisions: 34,
                  display: l10n.sheetFontSizeValue(_settings.fontSize.toInt()),
                  onChanged: (value) =>
                      _patch((s) => s.copyWith(fontSize: value)),
                ),
                _SliderTile(
                  label: l10n.sheetLineHeight,
                  value: _settings.lineHeight,
                  min: 1.0,
                  max: 2.5,
                  divisions: 30,
                  display: l10n.sheetLineHeightValue(
                    _settings.lineHeight.toStringAsFixed(2),
                  ),
                  onChanged: (value) =>
                      _patch((s) => s.copyWith(lineHeight: value)),
                ),
                _SliderTile(
                  label: l10n.sheetMarginLeft,
                  value: _settings.leftMargin,
                  min: 0,
                  max: 0.4,
                  divisions: 20,
                  display: l10n.sheetPercentValue(
                    (_settings.leftMargin * 100).round(),
                  ),
                  onChanged: (value) =>
                      _patch((s) => s.copyWith(leftMargin: value)),
                ),
                _SliderTile(
                  label: l10n.sheetMarginRight,
                  value: _settings.rightMargin,
                  min: 0,
                  max: 0.4,
                  divisions: 20,
                  display: l10n.sheetPercentValue(
                    (_settings.rightMargin * 100).round(),
                  ),
                  onChanged: (value) =>
                      _patch((s) => s.copyWith(rightMargin: value)),
                ),
                _SliderTile(
                  label: l10n.sheetLetterSpacing,
                  value: _settings.letterSpacing,
                  min: -1,
                  max: 3,
                  divisions: 16,
                  display: _settings.letterSpacing.toStringAsFixed(1),
                  onChanged: (value) =>
                      _patch((s) => s.copyWith(letterSpacing: value)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.sheetAlignCenter),
                  subtitle: Text(l10n.sheetAlignCenterHint),
                  value: _settings.alignCenter,
                  onChanged: (value) =>
                      _patch((s) => s.copyWith(alignCenter: value)),
                ),
                const SizedBox(height: TpTokens.space2),
                _sectionTitle(context, l10n.sheetSectionMirror),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.sheetMirrorX),
                  subtitle: Text(l10n.sheetMirrorXHint),
                  value: _settings.mirrorX,
                  onChanged: (value) =>
                      _patch((s) => s.copyWith(mirrorX: value)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.sheetMirrorY),
                  value: _settings.mirrorY,
                  onChanged: (value) =>
                      _patch((s) => s.copyWith(mirrorY: value)),
                ),
                _SliderTile(
                  label: l10n.sheetPrismDx,
                  value: _settings.prismDx,
                  min: -0.05,
                  max: 0.05,
                  divisions: 20,
                  display: '${(_settings.prismDx * 100).toStringAsFixed(1)}%',
                  onChanged: (value) =>
                      _patch((s) => s.copyWith(prismDx: value)),
                ),
                _SliderTile(
                  label: l10n.sheetPrismDy,
                  value: _settings.prismDy,
                  min: -0.05,
                  max: 0.05,
                  divisions: 20,
                  display: '${(_settings.prismDy * 100).toStringAsFixed(1)}%',
                  onChanged: (value) =>
                      _patch((s) => s.copyWith(prismDy: value)),
                ),
                const SizedBox(height: TpTokens.space2),
                _sectionTitle(context, l10n.sheetSectionScroll),
                _SliderTile(
                  label: l10n.sheetSpeed,
                  value: _settings.speed,
                  min: 0.2,
                  max: 10,
                  divisions: 49,
                  display: l10n.sheetSpeedValue(
                    _settings.speed.toStringAsFixed(1),
                  ),
                  onChanged: (value) => _patch((s) => s.copyWith(speed: value)),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _patch((s) => s.copyWith(
                          speed: ReaderSettings.defaults.speed,
                        )),
                    icon: const Icon(Icons.restart_alt),
                    label: Text(l10n.sheetSpeedReset),
                  ),
                ),
                _SliderTile(
                  label: l10n.sheetReadAhead,
                  value: _settings.readAheadRatio,
                  min: 0.2,
                  max: 0.6,
                  divisions: 16,
                  display: l10n.sheetPercentValue(
                    (_settings.readAheadRatio * 100).round(),
                  ),
                  onChanged: (value) =>
                      _patch((s) => s.copyWith(readAheadRatio: value)),
                ),
                _SliderTile(
                  label: l10n.sheetSmoothness,
                  value: _settings.smoothness,
                  min: 4,
                  max: 12,
                  divisions: 16,
                  display: _settings.smoothness.toStringAsFixed(1),
                  onChanged: (value) =>
                      _patch((s) => s.copyWith(smoothness: value)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.sheetLineStepFollow),
                  subtitle: Text(l10n.sheetLineStepHint),
                  value: _settings.lineStepFollow,
                  onChanged: (value) =>
                      _patch((s) => s.copyWith(lineStepFollow: value)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.sheetLatencyCompensation),
                  subtitle: Text(l10n.sheetLatencyCompensationHint),
                  value: _settings.latencyCompensation,
                  onChanged: (value) =>
                      _patch((s) => s.copyWith(latencyCompensation: value)),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: TpTokens.space1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sheetAsrModel,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<AsrModelChoice>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: AsrModelChoice.zh14m,
                            label: Text(l10n.sheetAsrModelZh14m),
                          ),
                          ButtonSegment(
                            value: AsrModelChoice.bilingualMixed,
                            label: Text(l10n.sheetAsrModelMixed),
                          ),
                        ],
                        selected: {_settings.asrModel},
                        onSelectionChanged: (selection) => _patch(
                          (s) => s.copyWith(asrModel: selection.first),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _settings.asrModel == AsrModelChoice.bilingualMixed
                            ? l10n.sheetAsrModelMixedHint
                            : l10n.sheetAsrModelZh14mHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        l10n.sheetAsrModelSwitchHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: TpTokens.space1),
                  child: Row(
                    children: [
                      Text(
                        l10n.sheetEndBehavior,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      SegmentedButton<ReaderEndBehavior>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: ReaderEndBehavior.stop,
                            label: Text(l10n.sheetEndBehaviorStop),
                          ),
                          ButtonSegment(
                            value: ReaderEndBehavior.loop,
                            label: Text(l10n.sheetEndBehaviorLoop),
                          ),
                        ],
                        selected: {_settings.endBehavior},
                        onSelectionChanged: (selection) => _patch(
                          (s) => s.copyWith(endBehavior: selection.first),
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.sheetPauseStop),
                  subtitle: Text(l10n.sheetPauseStopHint),
                  value: _settings.pauseStop,
                  onChanged: (value) =>
                      _patch((s) => s.copyWith(pauseStop: value)),
                ),
                const SizedBox(height: TpTokens.space2),
                _sectionTitle(context, l10n.sheetSectionMatch),
                Text(
                  l10n.sheetMatchHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: TpTokens.space1),
                Wrap(
                  spacing: TpTokens.space1,
                  runSpacing: TpTokens.space1,
                  children: [
                    for (final tolerance in MatchTolerance.values)
                      ChoiceChip(
                        label: Text(_matchLabel(l10n, tolerance)),
                        selected: _settings.matchTolerance == tolerance,
                        onSelected: (_) => _patch(
                          (s) => s.copyWith(matchTolerance: tolerance),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: TpTokens.space1),
                  child: Text(
                    _matchHint(l10n, _settings.matchTolerance),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.sheetKeepScreenOn),
                  subtitle: Text(l10n.sheetKeepScreenOnHint),
                  value: _settings.keepScreenOn,
                  onChanged: (value) =>
                      _patch((s) => s.copyWith(keepScreenOn: value)),
                ),
                if (widget.onOverlayChanged != null) ...[
                  const SizedBox(height: TpTokens.space2),
                  _sectionTitle(context, l10n.sheetSectionOverlay),
                  _SliderTile(
                    label: l10n.sheetOverlayWidth,
                    value: _overlay.widthDp.toDouble(),
                    min: 200,
                    max: 600,
                    divisions: 40,
                    display: l10n.sheetOverlayWidthValue(_overlay.widthDp),
                    onChanged: (value) => _patchOverlay(
                      (s) => s.copyWith(widthDp: value.round()),
                    ),
                  ),
                  _SliderTile(
                    label: l10n.sheetOverlayOpacity,
                    value: _overlay.opacity,
                    min: 0.3,
                    max: 1.0,
                    divisions: 14,
                    display: l10n.sheetPercentValue(
                      (_overlay.opacity * 100).round(),
                    ),
                    onChanged: (value) => _patchOverlay(
                      (s) => s.copyWith(opacity: value),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: TpTokens.space1),
                    child: Row(
                      children: [
                        Text(
                          l10n.sheetOverlayLines,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: 3,
                              label: Text(l10n.sheetOverlayLines3),
                            ),
                            ButtonSegment(
                              value: 5,
                              label: Text(l10n.sheetOverlayLines5),
                            ),
                          ],
                          selected: {_overlay.lineCount},
                          onSelectionChanged: (selection) => _patchOverlay(
                            (s) => s.copyWith(lineCount: selection.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    l10n.sheetOverlayHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: TpTokens.space2),
                Text(
                  l10n.sheetFooter,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 档位名称：只用于让用户看懂强弱顺序。
  String _matchLabel(AppLocalizations l10n, MatchTolerance tolerance) {
    return switch (tolerance) {
      MatchTolerance.veryStrict => l10n.matchVeryStrict,
      MatchTolerance.strict => l10n.matchStrict,
      MatchTolerance.standard => l10n.matchStandard,
      MatchTolerance.loose => l10n.matchLoose,
      MatchTolerance.veryLoose => l10n.matchVeryLoose,
    };
  }

  /// 一句用途说明：不暴露阈值、次数、前看行数等实现细节。
  String _matchHint(AppLocalizations l10n, MatchTolerance tolerance) {
    return switch (tolerance) {
      MatchTolerance.veryStrict => l10n.matchVeryStrictHint,
      MatchTolerance.strict => l10n.matchStrictHint,
      MatchTolerance.standard => l10n.matchStandardHint,
      MatchTolerance.loose => l10n.matchLooseHint,
      MatchTolerance.veryLoose => l10n.matchVeryLooseHint,
    };
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(
        top: TpTokens.space2,
        bottom: TpTokens.space1,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: TpTokens.space1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              Text(
                display,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          SizedBox(
            height: 36,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
