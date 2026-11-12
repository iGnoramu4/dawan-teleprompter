import 'package:flutter/services.dart';

/// 内置示例台本（M0 的 assets 台本，首启时写入数据库）。
const Map<String, String> _titles = {
  'demo_follow': '语音跟随演示',
  'speech_sample': '演讲示例',
  'team_update': '团队汇报示例',
};

Future<List<({String title, String text})>> loadSeedScripts() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final paths = manifest
      .listAssets()
      .where((asset) =>
          asset.startsWith('assets/scripts/') && asset.endsWith('.txt'))
      .toList()
    ..sort();

  final seeds = <({String title, String text})>[];
  for (final path in paths) {
    final base = path.split('/').last.replaceAll('.txt', '');
    seeds.add(
      (
        title: _titles[base] ?? base,
        text: await rootBundle.loadString(path),
      ),
    );
  }
  return seeds;
}
