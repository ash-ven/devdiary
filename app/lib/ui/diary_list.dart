import 'package:material_ui/material_ui.dart';

import '../models/diary_entry.dart';
import '../state/diary_store.dart';
import '../state/scope.dart';
import '../text/day_groups.dart';
import 'common.dart';
import 'type_mark.dart';

/// Il diario: ricerca, filtri per tipo, note raggruppate per giorno.
/// Con [compact] (telefono) l'intestazione scorre insieme alle note,
/// i filtri stanno su una riga scorrevole e le righe non mostrano i tag.
class DiaryList extends StatelessWidget {
  const DiaryList({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final diary = DevDiaryScope.of(context).diary;
    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 18,
        compact ? 12 : 18,
        compact ? 14 : 18,
        8,
      ),
      child: _header(context, diary),
    );
    final message = _message(context, diary);
    if (!compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(
            child:
                message ??
                ListView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                  children: _rows(context, diary),
                ),
          ),
        ],
      );
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: header),
        if (message != null)
          SliverFillRemaining(hasScrollBody: false, child: message)
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 88),
            sliver: SliverList.list(children: _rows(context, diary)),
          ),
      ],
    );
  }

  Widget _header(BuildContext context, DiaryStore diary) {
    final t = context.tokens;
    final l = context.l10n;
    final title = switch (diary.view) {
      DiaryView.favorites => l.navFavorites,
      DiaryView.trash => l.navTrash,
      _ => l.navDiary,
    };
    final filters = [
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
          onTap: () => diary.setType(diary.type == type ? null : type),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DemoNotice(),
        // Sul telefono il titolo della vista sta già nella barra in alto.
        if (!compact) ...[
          Row(
            children: [
              Expanded(
                child: Semantics(
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
              ),
              if (diary.view != DiaryView.trash)
                FilledButton.icon(
                  onPressed: diary.startNew,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l.newNote),
                  style: FilledButton.styleFrom(
                    backgroundColor: t.primary,
                    foregroundColor: t.onPrimary,
                    minimumSize: const Size(44, 40),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: diary.searchField,
          onChanged: diary.setSearch,
          style: TextStyle(color: t.ink, fontSize: 15),
          decoration: InputDecoration(
            hintText: compact ? l.paletteHint : l.searchHint,
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
        const SizedBox(height: 8),
        if (compact)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: filters),
          )
        else
          Wrap(spacing: 2, runSpacing: 2, children: filters),
        if (diary.tag != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: InputChip(
              label: Text('#${diary.tag}'),
              onDeleted: () => diary.setTag(null),
            ),
          ),
      ],
    );
  }

  /// Stato vuoto, errore o caricamento; null quando ci sono note da mostrare.
  Widget? _message(BuildContext context, DiaryStore diary) {
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
    return null;
  }

  List<Widget> _rows(BuildContext context, DiaryStore diary) {
    final t = context.tokens;
    return [
      for (final g in groupByDay(diary.entries, DateTime.now())) ...[
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
            showTags: !compact,
            onTap: () => diary.select(e.id),
          ),
      ],
    ];
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
    this.showTags = true,
  });
  final DiaryEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final bool showTags;

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
                if (showTags)
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

/// Avviso discreto al primo accesso: è una demo. Una volta chiuso non torna.
class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final settings = DevDiaryScope.of(context).settings;
    if (settings.demoNoticeDismissed) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: t.markBgNote,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l.demoNotice,
              style: TextStyle(color: t.markTxNote, fontSize: 13.5),
            ),
          ),
          IconButton(
            tooltip: l.close,
            icon: Icon(Icons.close, size: 18, color: t.markTxNote),
            onPressed: settings.dismissDemoNotice,
          ),
        ],
      ),
    );
  }
}
