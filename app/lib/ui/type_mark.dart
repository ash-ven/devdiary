import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.g.dart';
import 'common.dart';

const noteTypes = ['note', 'snippet', 'idea', 'errore', 'link'];

String typeLabel(AppLocalizations l, String type) => switch (type) {
  'snippet' => l.typeSnippet,
  'idea' => l.typeIdea,
  'errore' => l.typeErrore,
  'link' => l.typeLink,
  _ => l.typeNote,
};

String typeFilterLabel(AppLocalizations l, String type) => switch (type) {
  'snippet' => l.filterSnippet,
  'idea' => l.filterIdea,
  'errore' => l.filterErrore,
  'link' => l.filterLink,
  _ => l.filterNote,
};

/// Tinta (sfondo) e testo verificati per ogni tipo.
(Color, Color) typeColors(DevDiaryTokens t, String type) => switch (type) {
  'snippet' => (t.markBgSnippet, t.markTxSnippet),
  'idea' => (t.markBgIdea, t.markTxIdea),
  'errore' => (t.markBgErrore, t.markTxErrore),
  'link' => (t.markBgLink, t.markTxLink),
  _ => (t.markBgNote, t.markTxNote),
};

/// Il bordo irregolare di un tratto di evidenziatore.
const markerRadius = BorderRadius.only(
  topLeft: Radius.elliptical(3, 8),
  topRight: Radius.elliptical(8, 3),
  bottomRight: Radius.elliptical(4, 9),
  bottomLeft: Radius.elliptical(9, 4),
);

/// Tipo della nota come tratto di evidenziatore con l'etichetta scritta.
class TypeMark extends StatelessWidget {
  const TypeMark(this.type, {super.key});
  final String type;

  @override
  Widget build(BuildContext context) {
    final (bg, tx) = typeColors(context.tokens, type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: markerRadius),
      child: Text(
        typeLabel(context.l10n, type),
        style: TextStyle(
          color: tx,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          height: 1.5,
        ),
      ),
    );
  }
}

/// Etichetta "Esempio" per le note di esempio in sola lettura.
class SampleLabel extends StatelessWidget {
  const SampleLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: t.ruleStrong),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        context.l10n.sample,
        style: TextStyle(color: t.ink2, fontSize: 12, height: 1.5),
      ),
    );
  }
}
