import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/diary_entry.dart';
import '../state/diary_store.dart';
import '../state/scope.dart';
import 'common.dart';
import 'type_mark.dart';

Future<void> showCommandPalette(BuildContext context) {
  final diary = DevDiaryScope.of(context).diary;
  if (diary.all.isEmpty) diary.loadAll();
  return showDialog<void>(
    context: context,
    builder: (_) => const CommandPalette(),
  );
}

/// Note caricate che contengono [query] nel titolo, nel testo o nel codice.
List<DiaryEntry> paletteMatches(List<DiaryEntry> entries, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return entries.take(8).toList();
  return entries
      .where(
        (e) =>
            e.title.toLowerCase().contains(q) ||
            e.content.toLowerCase().contains(q) ||
            (e.code ?? '').toLowerCase().contains(q),
      )
      .take(8)
      .toList();
}

/// Ricerca rapida: frecce per scegliere, Invio apre, Esc chiude.
class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key});

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  String _query = '';
  int _index = 0;

  void _open(DiaryStore diary, DiaryEntry e) {
    Navigator.of(context).pop();
    diary.open(e.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final diary = DevDiaryScope.of(context).diary;
    final matches = paletteMatches(
      diary.all.isNotEmpty ? diary.all : diary.entries,
      _query,
    );
    final index = matches.isEmpty ? 0 : _index.clamp(0, matches.length - 1);

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
      backgroundColor: t.sheet,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Focus(
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                    return KeyEventResult.ignored;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    setState(
                      () => _index =
                          (index + 1) % (matches.isEmpty ? 1 : matches.length),
                    );
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    setState(
                      () => _index = matches.isEmpty
                          ? 0
                          : (index - 1 + matches.length) % matches.length,
                    );
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() {
                    _query = v;
                    _index = 0;
                  }),
                  onSubmitted: (_) {
                    if (matches.isNotEmpty) _open(diary, matches[index]);
                  },
                  style: TextStyle(color: t.ink, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: l.paletteHint,
                    prefixIcon: Icon(Icons.search, color: t.ink3),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: t.ruleStrong.withValues(alpha: .4)),
            if (matches.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(l.paletteEmpty, style: TextStyle(color: t.ink2)),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(6),
                  children: [
                    for (var i = 0; i < matches.length; i++)
                      Tappable(
                        selected: i == index,
                        color: i == index ? t.ink.withValues(alpha: .07) : null,
                        onTap: () => _open(diary, matches[i]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              TypeMark(matches[i].type),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  matches[i].title,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: t.ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
