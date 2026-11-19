import 'package:dev_diary/theme/devdiary_theme.dart';
import 'package:dev_diary/theme/tokens.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('tokens match the verified palette', () {
    expect(DevDiaryTokens.light.paper, const Color(0xFFECEFF5));
    expect(
      DevDiaryTokens.dark.markBgNote,
      const Color.fromRGBO(183, 155, 255, .28),
    );
  });

  test('light and dark themes carry the tokens', () {
    final dark = buildTheme(Brightness.dark).extension<DevDiaryTokens>()!;
    final light = buildTheme(Brightness.light).extension<DevDiaryTokens>()!;
    expect(dark.sheet, const Color(0xFF16264A));
    expect(light.sheet, const Color(0xFFF7F8FC));
  });

  test('code font has ligatures off', () {
    expect(devDiaryCodeStyle.fontFamily, 'JetBrainsMono');
    expect(devDiaryCodeStyle.fontFeatures, [
      const FontFeature.disable('liga'),
      const FontFeature.disable('calt'),
    ]);
  });
}
