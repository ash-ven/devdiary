import 'package:material_ui/material_ui.dart';

import 'devdiary_fonts.dart';
import 'tokens.g.dart';

/// Stile del codice: JetBrains Mono, legature disattivate.
const devDiaryCodeStyle = TextStyle(
  fontFamily: DevDiaryFonts.code,
  fontFeatures: [FontFeature.disable('liga')],
);

/// Tema chiaro o scuro costruito dai token generati.
ThemeData buildTheme(Brightness brightness) {
  final t = brightness == Brightness.dark
      ? DevDiaryTokens.dark
      : DevDiaryTokens.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: t.primary,
    onPrimary: t.onPrimary,
    secondary: t.accent,
    onSecondary: t.ink,
    error: t.accentText,
    onError: t.paper,
    surface: t.sheet,
    onSurface: t.ink,
    outline: t.ruleStrong,
  );
  final base = ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: t.paper,
    fontFamily: DevDiaryFonts.ui,
    focusColor: t.focus,
    extensions: [t],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: t.ink, displayColor: t.ink),
  );
}
