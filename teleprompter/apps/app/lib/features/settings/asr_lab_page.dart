import 'dart:convert';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_log.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/asr_lab/asr_lab_settings.dart';

/// 开发/实验面板：端点与音频采集参数（仅调试构建可达）。
///
/// 改动立即持久化，停止并重新开启麦克风后生效；默认值与正式版一致。
class AsrLabPage extends ConsumerStatefulWidget {
  const AsrLabPage({super.key});

  @override
  ConsumerState<AsrLabPage> createState() => _AsrLabPageState();
}

class _AsrLabPageState extends ConsumerState<AsrLabPage> {
  static const List<int> _bufferOptions = [0, 100, 200, 300, 500];

  AsrLabSettings _settings = AsrLabSettings.defaults;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await loadAsrLabSettings(ref.read(scriptRepositoryProvider));
    if (!mounted) return;
    setState(() {
      _settings = loaded;
      _loaded = true;
    });
  }

  Future<void> _update(AsrLabSettings next, String field) async {
    final normalized = next.normalized();
    setState(() => _settings = normalized);
    await saveAsrLabSettings(
      ref.read(scriptRepositoryProvider),
      normalized,
    );
    AppLog.instance.event('settings', 'asr_lab_changed', {
      'field': field,
      ...normalized.toJson(),
    });
  }

  Future<void> _restore() async {
    await _update(AsrLabSettings.defaults, 'restore');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).asrLabRestored)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.asrLabTitle)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                TpTokens.space3,
                TpTokens.space3,
                TpTokens.space3,
                TpTokens.space8,
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(TpTokens.space3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(TpTokens.radiusSmall),
                  ),
                  child: Text(
                    l10n.asrLabWarning,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: TpTokens.space4),
                _sectionTitle(theme, l10n.asrLabEndpointSection),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _sliderTile(
                        title: l10n.asrLabRule1,
                        value: _settings.rule1MinTrailingSilence,
                        min: 0.4,
                        max: 3.0,
                        divisions: 26,
                        onChanged: (value) => _update(
                          _settings.copyWith(rule1MinTrailingSilence: value),
                          'rule1MinTrailingSilence',
                        ),
                      ),
                      _sliderTile(
                        title: l10n.asrLabRule2,
                        value: _settings.rule2MinTrailingSilence,
                        min: 0.4,
                        max: 2.4,
                        divisions: 20,
                        onChanged: (value) => _update(
                          _settings.copyWith(rule2MinTrailingSilence: value),
                          'rule2MinTrailingSilence',
                        ),
                      ),
                      const SizedBox(height: TpTokens.space2),
                    ],
                  ),
                ),
                const SizedBox(height: TpTokens.space4),
                _sectionTitle(theme, l10n.asrLabAudioSection),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text(l10n.asrLabAgc),
                        value: _settings.autoGain,
                        onChanged: (value) => _update(
                          _settings.copyWith(autoGain: value),
                          'autoGain',
                        ),
                      ),
                      SwitchListTile(
                        title: Text(l10n.asrLabNs),
                        value: _settings.noiseSuppress,
                        onChanged: (value) => _update(
                          _settings.copyWith(noiseSuppress: value),
                          'noiseSuppress',
                        ),
                      ),
                      SwitchListTile(
                        title: Text(l10n.asrLabAec),
                        value: _settings.echoCancel,
                        onChanged: (value) => _update(
                          _settings.copyWith(echoCancel: value),
                          'echoCancel',
                        ),
                      ),
                      const Divider(height: 1),
                      _choiceTile(
                        title: l10n.asrLabAudioSource,
                        child: SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(
                              value: true,
                              label: Text(l10n.asrLabSourceVoice),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text(l10n.asrLabSourceMic),
                            ),
                          ],
                          selected: {_settings.preferVoiceRecognition},
                          onSelectionChanged: (values) => _update(
                            _settings.copyWith(
                              preferVoiceRecognition: values.first,
                            ),
                            'audioSource',
                          ),
                        ),
                      ),
                      _choiceTile(
                        title: l10n.asrLabBuffer,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: TpTokens.space2,
                              children: [
                                for (final ms in _bufferOptions)
                                  ChoiceChip(
                                    label: Text(
                                      ms == 0 ? l10n.asrLabBufferRaw : '$ms ms',
                                    ),
                                    selected: _settings.bufferMs == ms,
                                    onSelected: (_) => _update(
                                      _settings.copyWith(bufferMs: ms),
                                      'bufferMs',
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: TpTokens.space1),
                            Text(
                              l10n.asrLabBufferNote,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: TpTokens.space2),
                    ],
                  ),
                ),
                const SizedBox(height: TpTokens.space4),
                Card(
                  margin: EdgeInsets.zero,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(TpTokens.space3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.asrLabCurrent,
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: TpTokens.space1),
                        SelectableText(
                          const JsonEncoder.withIndent('  ')
                              .convert(_settings.toJson()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: TpTokens.space4),
                FilledButton.tonalIcon(
                  onPressed: _restore,
                  icon: const Icon(Icons.restart_alt),
                  label: Text(l10n.asrLabRestore),
                ),
              ],
            ),
    );
  }

  Widget _sliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    final label = '${value.toStringAsFixed(1)} s';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TpTokens.space4,
        TpTokens.space2,
        TpTokens.space4,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: theme.textTheme.titleSmall),
              ),
              Text(label, style: theme.textTheme.labelLarge),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: label,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _choiceTile({required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TpTokens.space4,
        TpTokens.space2,
        TpTokens.space4,
        TpTokens.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: TpTokens.space2),
          Align(alignment: Alignment.centerLeft, child: child),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TpTokens.space1),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
