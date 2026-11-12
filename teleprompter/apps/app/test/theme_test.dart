import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('深浅主题的文字颜色均为正色，不会退化为空值', () {
    final light = TpTheme.light().textTheme.titleMedium?.color;
    final dark = TpTheme.dark().textTheme.titleMedium?.color;
    expect(light, isNotNull);
    expect(dark, isNotNull);
    expect(light!.computeLuminance(), lessThan(0.3));
    expect(dark!.computeLuminance(), greaterThan(0.7));
  });

  test('强调色种子可替换壳层主色', () {
    final theme = TpTheme.light(seed: TpAccent.teal.seed);
    expect(theme.colorScheme.brightness, Brightness.light);
    expect(TpAccent.fromId('teal'), TpAccent.teal);
    expect(TpAccent.fromId('unknown'), TpAccent.indigo);
  });
}
