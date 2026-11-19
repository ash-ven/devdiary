import 'package:material_ui/material_ui.dart';

import '../models/diary_entry.dart';
import '../services/api_exception.dart';
import '../state/diary_store.dart';
import '../state/scope.dart';
import '../text/day_groups.dart';
import 'code_block.dart';
import 'common.dart';
import 'markdown_view.dart';
import 'type_mark.dart';

/// Un'azione sulla nota: pulsante con etichetta nel foglio largo,
/// icona nella barra in alto sul telefono.
class NoteAction {
  const NoteAction(
    this.icon,
    this.label,
    this.onPressed, {
    this.accent = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool accent;
}

/// Azioni disponibili per [entry]: nel cestino Ripristina ed Elimina,
/// altrimenti Modifica, Preferito e Sposta nel cestino (disattivate per gli esempi).
List<NoteAction> noteActions(BuildContext context, DiaryEntry entry) {
  final t = context.tokens;
  final l = context.l10n;
  final diary = DevDiaryScope.of(context).diary;

  Future<void> run(Future<void> Function() action, [String? done]) async {
    try {
      await action();
      if (done != null && context.mounted) showMessage(context, done);
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, errorText(context, e));
    }
  }

  Future<void> confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteConfirmTitle),
        content: Text(l.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: t.accentText,
              foregroundColor: t.paper,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.deleteForever),
          ),
        ],
      ),
    );
    if (ok == true) await run(() => diary.deletePermanently(entry), l.deleted);
  }

  if (diary.view == DiaryView.trash) {
    return [
      NoteAction(
        Icons.restore,
        l.restore,
        () => run(() => diary.restore(entry), l.restored),
      ),
      NoteAction(
        Icons.delete_forever_outlined,
        l.deleteForever,
        confirmDelete,
        accent: true,
      ),
    ];
  }
  final sample = entry.isSample;
  return [
    NoteAction(
      Icons.edit_outlined,
      l.actionEdit,
      sample ? null : () => diary.startEdit(entry),
    ),
    NoteAction(
      entry.isFavorite ? Icons.star : Icons.star_border,
      entry.isFavorite ? l.actionUnfavorite : l.actionFavorite,
      sample ? null : () => run(() => diary.toggleFavorite(entry)),
      accent: entry.isFavorite,
    ),
    NoteAction(
      Icons.delete_outline,
      l.actionTrash,
      sample ? null : () => run(() => diary.moveToTrash(entry), l.movedToTrash),
    ),
  ];
}

/// Il foglio della nota, con il margine rosa del quaderno (solo sugli schermi larghi).
/// Sul telefono le azioni stanno nella barra in alto, non nel foglio.
class NoteSheet extends StatelessWidget {
  const NoteSheet({super.key, required this.entry, this.narrow = false});
  final DiaryEntry entry;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final diary = DevDiaryScope.of(context).diary;
    final created = localTime(entry.createdAt);
    final inTrash = diary.view == DiaryView.trash;
    final actions = narrow ? const <NoteAction>[] : noteActions(context, entry);

    return Container(
      decoration: BoxDecoration(
        color: t.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        boxShadow: sheetShadow(t),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (!narrow)
            Positioned(
              left: 64,
              top: 0,
              bottom: 0,
              width: 2,
              child: ColoredBox(color: t.accent.withValues(alpha: .45)),
            ),
          SingleChildScrollView(
            padding: narrow
                ? const EdgeInsets.fromLTRB(18, 18, 18, 40)
                : const EdgeInsets.fromLTRB(88, 34, 48, 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TypeMark(entry.type),
                      if (created != null)
                        Text(
                          l.dateAt(
                            italianDate(created, DateTime.now()),
                            hourMinute(created),
                          ),
                          style: TextStyle(color: t.ink3, fontSize: 13),
                        ),
                      if (entry.isSample) const SampleLabel(),
                      for (final a in actions)
                        _ActionButton(
                          icon: a.icon,
                          label: a.label,
                          onPressed: a.onPressed,
                          accent: a.accent,
                        ),
                    ],
                  ),
                  if (entry.isSample && !inTrash)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l.sampleReadOnlyHint,
                        style: TextStyle(color: t.ink3, fontSize: 13),
                      ),
                    ),
                  SizedBox(height: narrow ? 14 : 18),
                  Semantics(
                    header: true,
                    child: Text(
                      entry.title,
                      style: TextStyle(
                        color: t.ink,
                        fontSize: narrow ? 27 : 40,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: narrow ? -.6 : -1.2,
                      ),
                    ),
                  ),
                  if (entry.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          for (final tag in entry.tags)
                            Text(
                              '#$tag',
                              style: TextStyle(color: t.ink2, fontSize: 13.5),
                            ),
                        ],
                      ),
                    ),
                  SizedBox(height: narrow ? 14 : 20),
                  MarkdownView(entry.content),
                  if ((entry.code ?? '').isNotEmpty)
                    CodeBlock(code: entry.code!, language: entry.language),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.accent = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = accent ? t.accentText : t.ink2;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: onPressed == null ? t.ink3 : color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: t.ink3,
        minimumSize: const Size(44, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: BorderSide(color: accent ? t.accent : t.ruleStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
