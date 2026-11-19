import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../services/api_exception.dart';
import '../theme/tokens.g.dart';

extension DevDiaryContext on BuildContext {
  DevDiaryTokens get tokens => Theme.of(this).extension<DevDiaryTokens>()!;
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

/// Ombra leggera dei fogli, presa dai token del tema.
List<BoxShadow> sheetShadow(DevDiaryTokens t) => [
  BoxShadow(
    color: t.ink.withValues(alpha: .14),
    blurRadius: 24,
    spreadRadius: -14,
    offset: const Offset(0, 10),
  ),
];

/// Testo dell'errore: quello dell'ARB per il codice, altrimenti il messaggio dell'API.
String errorText(BuildContext context, ApiException e) {
  final l = context.l10n;
  return switch (e.code) {
    'SAMPLE_READ_ONLY' => l.errorSampleReadOnly,
    'DEMO_LIMIT_REACHED' => l.errorDemoLimit,
    'VISITOR_REQUIRED' => l.errorVisitorRequired,
    'NOT_FOUND' => l.errorNotFound,
    'DATABASE_UNAVAILABLE' => l.errorDatabase,
    'TIMEOUT' => l.errorTimeout,
    'NETWORK' => l.errorNetwork,
    'FIELD_INVALID' => l.errorFieldInvalid,
    'INTERNAL_ERROR' => l.errorInternal,
    _ => e.message,
  };
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Area cliccabile con anello di focus da tastiera di 2px staccato di 2px.
class Tappable extends StatefulWidget {
  const Tappable({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 10,
    this.color,
    this.shadow,
    this.semanticLabel,
    this.selected = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final Color? color;
  final List<BoxShadow>? shadow;
  final String? semanticLabel;
  final bool selected;

  @override
  State<Tappable> createState() => _TappableState();
}

class _TappableState extends State<Tappable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = BorderRadius.circular(widget.radius);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius + 4),
          border: Border.all(
            color: _focused ? t.focus : Colors.transparent,
            width: 2,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: r, boxShadow: widget.shadow),
          child: Material(
            color: widget.color ?? Colors.transparent,
            borderRadius: r,
            child: InkWell(
              borderRadius: r,
              onTap: widget.onTap,
              onFocusChange: (f) => setState(() => _focused = f),
              focusColor: Colors.transparent,
              hoverColor: t.ink.withValues(alpha: .05),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Carta a quadretti dietro tutta l'app.
class NotebookPaper extends StatelessWidget {
  const NotebookPaper({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _GridPainter(
        t.primary.withValues(alpha: dark ? .10 : .07),
        t.paper,
      ),
      child: child,
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.line, this.background);
  final Color line;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final p = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.line != line || old.background != background;
}
