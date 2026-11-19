import 'package:material_ui/material_ui.dart';

import '../models/diary_entry.dart';
import '../state/diary_store.dart';
import '../state/scope.dart';
import '../text/day_groups.dart';
import 'common.dart';
import 'type_mark.dart';

/// Il diario: ricerca, filtri per tipo, note raggruppate per giorno.
class DiaryList extends StatelessWidget {
  const DiaryList({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final diary = DevDiaryScope.of(context).diary;
    final title = switch (diary.view) {
      DiaryView.favorites => l.navFavorites,
      DiaryView.trash => l.navTrash,
      _ => l.navDiary,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    color: t.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: diary.setSearch,
                style: TextStyle(color: t.ink, fontSize: 15),
                decoration: InputDecoration(
                  hintText: l.searchHint,
                  hintStyle: TextStyle(color: t.ink3),
                  prefixIcon: Icon(Icons.search, color: t.ink3, size: 19),
                  isDense: true,
                  filled: true,
                  fillColor: t.sheet,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: t.ruleStrong),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: t.focus, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 2,
                runSpacing: 2,
                children: [
                  _Filter(
                    label: l.filterAll,
                    selected: diary.type == null,
                    onTap: () => diary.setType(null),
                  ),
                  for (final type in noteTypes)
                    _Filter(
                      label: typeFilterLabel(l, type),
                      selected: diary.type == type,
                      colors: typeColors(t, type),
                      onTap: () =>
                          diary.setType(diary.type == type ? null : type),
                    ),
                ],
              ),
              if (diary.tag != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: InputChip(
                    label: Text('#${diary.tag}'),
                    onDeleted: () => diary.setTag(null),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _body(context, diary)),
      ],
    );
  }

  Widget _body(BuildContext context, DiaryStore diary) {
    final t = context.tokens;
    final l = context.l10n;
    if (diary.error != null && diary.entries.isEmpty) {
      return _Message(
        text: errorText(context, diary.error!),
        action: l.retry,
        onAction: diary.load,
      );
    }
    if (diary.loading && diary.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (diary.entries.isEmpty) {
      if (diary.hasFilters) {
        return _Message(
          text: l.noFilterResults,
          action: l.clearFilters,
          onAction: diary.clearFilters,
        );
      }
      return _Message(
        text: switch (diary.view) {
          DiaryView.favorites => l.emptyFavorites,
          DiaryView.trash => l.emptyTrash,
          _ => l.emptyDiary,
        },
      );
    }
    final groups = groupByDay(diary.entries, DateTime.now());
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      children: [
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 4),
            child: Semantics(
              header: true,
              child: Text(
                g.label,
                style: TextStyle(
                  color: t.ink2,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          for (final e in g.entries)
            _Row(
              entry: e,
              selected: e.id == diary.selectedId,
              onTap: () => diary.select(e.id),
            ),
        ],
      ],
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.selected,
    required this.onTap,
    this.colors,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final (Color, Color)? colors;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bg = selected ? (colors?.$1 ?? t.ink.withValues(alpha: .1)) : null;
    final fg = selected ? (colors?.$2 ?? t.ink) : t.ink2;
    return Tappable(
      onTap: onTap,
      selected: selected,
      radius: 8,
      color: bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

String _excerpt(String md) => md
    .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
    .replaceAll(RegExp(r'[#*_`>\[\]]'), '')
    .replaceAll(RegExp(r'\(https?://[^)]*\)'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class _Row extends StatelessWidget {
  const _Row({
    required this.entry,
    required this.selected,
    required this.onTap,
  });
  final DiaryEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    return Tappable(
      onTap: onTap,
      selected: selected,
      color: selected ? t.sheet : null,
      shadow: selected ? sheetShadow(t) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.ink,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
                if (entry.isFavorite)
                  Semantics(
                    label: l.favoriteSemantics,
                    child: Icon(Icons.star, size: 17, color: t.accent),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _excerpt(entry.content),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.ink2, fontSize: 13.5),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                TypeMark(entry.type),
                const SizedBox(width: 8),
                if (entry.isSample) ...[
                  const SampleLabel(),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    entry.tags.map((tag) => '#$tag').join(' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.ink3, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: t.ink2, fontSize: 15),
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}
