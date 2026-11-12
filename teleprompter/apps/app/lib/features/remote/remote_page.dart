import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../shared/remote/remote_protocol.dart';
import 'remote_client.dart';
import 'scan_page.dart';

/// 扫码入口（测试可注入 fake，避免启动相机）。
typedef RemoteScanLauncher = Future<RemotePairing?> Function(
  BuildContext context,
);

/// 遥控端页面（E6-2）：扫码或粘贴配对串连接主控端，展示行号进度并发送控制命令。
class RemotePage extends StatefulWidget {
  const RemotePage({
    super.key,
    this.connector,
    this.clientFactory,
    this.scanLauncher,
  });

  /// 传输连接器（测试可注入 fake）。
  final RemoteTransportConnector? connector;

  /// 客户端工厂（测试可注入短重试间隔的实例）。
  final RemoteClient Function(RemotePairing pairing)? clientFactory;

  /// 扫码启动器（默认打开 [ScanPage]）。
  final RemoteScanLauncher? scanLauncher;

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> {
  final TextEditingController _pairingController = TextEditingController();
  RemoteClient? _client;
  RemotePairing? _lastPairing;
  String? _inputError;

  @override
  void dispose() {
    _client?.dispose();
    _pairingController.dispose();
    super.dispose();
  }

  RemoteClient _createClient(RemotePairing pairing) {
    final factory = widget.clientFactory;
    if (factory != null) return factory(pairing);
    return RemoteClient(pairing: pairing, connector: widget.connector);
  }

  void _connectFromInput() {
    final pairing = RemotePairing.tryParse(_pairingController.text);
    if (pairing == null) {
      setState(() {
        _inputError = AppLocalizations.of(context).remoteInvalidPairing;
      });
      return;
    }
    _startClient(pairing);
  }

  Future<RemotePairing?> _openScanner(BuildContext context) {
    return Navigator.of(context).push<RemotePairing>(
      MaterialPageRoute<RemotePairing>(builder: (_) => const ScanPage()),
    );
  }

  Future<void> _scan() async {
    final l10n = AppLocalizations.of(context);
    final launcher = widget.scanLauncher ?? _openScanner;
    if (widget.scanLauncher == null && !supportsQrScanning) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.remoteScanUnsupported)),
      );
      return;
    }
    final pairing = await launcher(context);
    if (!mounted || pairing == null) return;
    _pairingController.text = pairing.toUriString();
    _startClient(pairing);
  }

  void _startClient(RemotePairing pairing) {
    _client?.dispose();
    final client = _createClient(pairing);
    _lastPairing = pairing;
    _inputError = null;
    client.addListener(_onClientChanged);
    setState(() => _client = client);
    unawaited(client.connect());
  }

  void _onClientChanged() {
    if (mounted) setState(() {});
  }

  void _disconnect() {
    final client = _client;
    if (client == null) return;
    unawaited(client.disconnect());
    _pairingController.text = _lastPairing?.toUriString() ?? '';
  }

  void _send(String action, {double? delta, bool? value}) {
    _client?.sendCommand(action, delta: delta, value: value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final client = _client;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.remoteTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(TpTokens.space4),
          children: [
            if (client == null ||
                client.state == RemoteConnectionState.idle) ...[
              _buildPairingForm(l10n),
            ] else ...[
              _buildConnectionStatus(l10n, client),
              const SizedBox(height: TpTokens.space3),
              if (client.remoteState != null)
                _buildStateCard(l10n, client.remoteState!),
              if (client.state == RemoteConnectionState.connected ||
                  client.state == RemoteConnectionState.disconnected) ...[
                const SizedBox(height: TpTokens.space3),
                _buildControls(l10n, client.remoteState),
              ],
              if (client.error != null &&
                  client.state != RemoteConnectionState.failed) ...[
                const SizedBox(height: TpTokens.space2),
                Text(
                  client.error!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPairingForm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.remoteRemoteHint),
        const SizedBox(height: TpTokens.space4),
        TextField(
          controller: _pairingController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: l10n.remotePairingLabel,
            hintText: l10n.remotePairingHint,
            errorText: _inputError,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: TpTokens.space3),
        Wrap(
          spacing: TpTokens.space2,
          runSpacing: TpTokens.space1,
          children: [
            FilledButton.icon(
              onPressed: _connectFromInput,
              icon: const Icon(Icons.link),
              label: Text(l10n.remoteConnect),
            ),
            OutlinedButton.icon(
              onPressed: _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(l10n.remoteScan),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectionStatus(AppLocalizations l10n, RemoteClient client) {
    return switch (client.state) {
      RemoteConnectionState.connecting => Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: TpTokens.space2),
            Text(l10n.remoteConnecting),
          ],
        ),
      RemoteConnectionState.connected => Row(
          children: [
            Icon(Icons.link, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: TpTokens.space2),
            Text(l10n.remoteConnected),
          ],
        ),
      RemoteConnectionState.disconnected => Row(
          children: [
            const Icon(Icons.sync_problem),
            const SizedBox(width: TpTokens.space2),
            Expanded(child: Text(l10n.remoteConnectionLost)),
          ],
        ),
      RemoteConnectionState.failed => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(client.error ?? l10n.remoteFailed),
            const SizedBox(height: TpTokens.space2),
            FilledButton.tonal(
              onPressed: () => unawaited(client.connect()),
              child: Text(l10n.remoteReconnect),
            ),
          ],
        ),
      RemoteConnectionState.idle => const SizedBox.shrink(),
    };
  }

  Widget _buildStateCard(AppLocalizations l10n, RemoteState state) {
    final total = state.rowCount > 0 ? state.rowCount : state.lineCount;
    final current = state.rowCount > 0 ? state.anchorRow : state.anchorLine;
    final text =
        state.anchorRowText.isNotEmpty ? state.anchorRowText : state.anchorText;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(TpTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.scriptTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: TpTokens.space2),
            Text(
              text.isEmpty ? '—' : text,
              style: Theme.of(context).textTheme.headlineSmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: TpTokens.space2),
            Text(
              l10n.remoteLineStatus(
                current + 1,
                total == 0 ? current + 1 : total,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: TpTokens.space2),
            LinearProgressIndicator(
              value: (state.rowCount > 0 ? state.rowProgress : state.progress)
                  .clamp(0.0, 1.0),
            ),
            const SizedBox(height: TpTokens.space2),
            Wrap(
              spacing: TpTokens.space2,
              runSpacing: TpTokens.space1,
              children: [
                _badge(
                  state.playing ? l10n.remotePlaying : l10n.remotePaused,
                  state.playing ? Icons.play_arrow : Icons.pause,
                ),
                _badge(
                  l10n.remoteSpeed(state.speed.toStringAsFixed(1)),
                  Icons.speed,
                ),
                if (state.mirrored) _badge(l10n.remoteMirror, Icons.flip),
                if (state.locked) _badge(l10n.remoteLock, Icons.lock),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(text),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildControls(AppLocalizations l10n, RemoteState? state) {
    final mirrored = state?.mirrored ?? false;
    final locked = state?.locked ?? false;
    final playing = state?.playing ?? false;
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: TpTokens.space2,
          runSpacing: TpTokens.space1,
          children: [
            IconButton(
              tooltip: l10n.remotePrevLine,
              onPressed:
                  locked ? null : () => _send(RemoteProtocol.actionPrevLine),
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton.filledTonal(
              tooltip: playing ? l10n.remotePause : l10n.remotePlay,
              onPressed: locked
                  ? null
                  : () => _send(
                        playing
                            ? RemoteProtocol.actionPause
                            : RemoteProtocol.actionPlay,
                      ),
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            ),
            IconButton(
              tooltip: l10n.remoteNextLine,
              onPressed:
                  locked ? null : () => _send(RemoteProtocol.actionNextLine),
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton(
              tooltip: l10n.remoteSpeedDown,
              onPressed: locked
                  ? null
                  : () => _send(RemoteProtocol.actionSpeed, delta: -0.2),
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              tooltip: l10n.remoteSpeedUp,
              onPressed: locked
                  ? null
                  : () => _send(RemoteProtocol.actionSpeed, delta: 0.2),
              icon: const Icon(Icons.add),
            ),
            IconButton(
              tooltip: l10n.remoteMirror,
              onPressed: () => _send(
                RemoteProtocol.actionMirror,
                value: !mirrored,
              ),
              icon: Icon(Icons.flip, color: mirrored ? primary : null),
            ),
            IconButton(
              tooltip: locked ? l10n.remoteUnlock : l10n.remoteLock,
              onPressed: () => _send(RemoteProtocol.actionLock, value: !locked),
              icon: Icon(locked ? Icons.lock : Icons.lock_open),
            ),
          ],
        ),
        const SizedBox(height: TpTokens.space2),
        OutlinedButton.icon(
          onPressed: _disconnect,
          icon: const Icon(Icons.link_off),
          label: Text(l10n.remoteDisconnect),
        ),
      ],
    );
  }
}
