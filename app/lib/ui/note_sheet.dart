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

/// Il foglio della nota, con il margine rosa del quaderno.
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
    final marginX = narrow ? 20.0 : 64.0;
    final inTrash = diary.view == DiaryView.trash;

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
      if (ok == true) {
        await run(() => diary.deletePermanently(entry), l.deleted);
      }
    }

    final actions = inTrash
        ? [
            _ActionButton(
              icon: Icons.restore,
              label: l.restore,
              onPressed: () => run(() => diary.restore(entry), l.restored),
            ),
            _ActionButton(
              icon: Icons.delete_forever_outlined,
              label: l.deleteForever,
              accent: true,
              onPressed: confirmDelete,
            ),
          ]
        : [
            _ActionButton(
              icon: Icons.edit_outlined,
              label: l.actionEdit,
              onPressed: entry.isSample ? null : () => diary.startEdit(entry),
            ),
            _ActionButton(
              icon: entry.isFavorite ? Icons.star : Icons.star_border,
              label: entry.isFavorite ? l.actionUnfavorite : l.actionFavorite,
              accent: entry.isFavorite,
              onPressed: entry.isSample
                  ? null
                  : () => run(() => diary.toggleFavorite(entry)),
            ),
            _ActionButton(
              icon: Icons.delete_outline,
              label: l.actionTrash,
              onPressed: entry.isSample
                  ? null
                  : () => run(() => diary.moveToTrash(entry), l.movedToTrash),
            ),
          ];

    return Container(
      decoration: BoxDecoration(
        color: t.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        boxShadow: sheetShadow(t),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: marginX,
            top: 0,
            bottom: 0,
            width: 2,
            child: ColoredBox(color: t.accent.withValues(alpha: .45)),
          ),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              marginX + 24,
              narrow ? 20 : 34,
              narrow ? 18 : 48,
              48,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
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
                      ...actions,
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
                  const SizedBox(height: 18),
                  Semantics(
                    header: true,
                    child: Text(
                      entry.title,
                      style: TextStyle(
                        color: t.ink,
                        fontSize: narrow ? 30 : 40,
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                        letterSpacing: -1.2,
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
                  const SizedBox(height: 20),
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
