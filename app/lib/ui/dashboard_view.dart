import 'package:material_ui/material_ui.dart';

import '../models/diary_entry.dart';
import '../state/scope.dart';
import '../text/activity.dart';
import '../text/day_groups.dart';
import '../theme/tokens.g.dart';
import 'common.dart';
import 'type_mark.dart';

Color strongColor(DevDiaryTokens t, String type) => switch (type) {
  'snippet' => t.strongSnippet,
  'idea' => t.strongIdea,
  'errore' => t.strongErrore,
  'link' => t.strongLink,
  _ => t.strongNote,
};

/// Dashboard: riepilogo, mappa dell'attività, note per tipo, tag, ultimi errori.
class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 820;
    final t = context.tokens;
    final l = context.l10n;
    final diary = DevDiaryScope.of(context).diary;
    final all = diary.all;
    final now = DateTime.now();

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                color: t.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );

    final counts = {
      for (final type in noteTypes)
        type: all.where((e) => e.type == type).length,
    };
    final maxCount = counts.values.fold(0, (a, b) => a > b ? a : b);
    final errors = all.where((e) => e.type == 'errore').take(3).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        narrow ? 18 : 32,
        narrow ? 14 : 28,
        narrow ? 18 : 32,
        48,
      ),
      children: [
        Text(
          l.dashTitle,
          style: TextStyle(
            color: t.ink,
            fontSize: narrow ? 28 : 40,
            fontWeight: FontWeight.w800,
            letterSpacing: narrow ? -.8 : -1.4,
          ),
        ),
        const SizedBox(height: 10),
        if (all.isEmpty)
          Text(l.dashEmpty, style: TextStyle(color: t.ink2, fontSize: 16))
        else ...[
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l.dashTotal(all.length),
                style: TextStyle(color: t.ink2, fontSize: 17),
              ),
              for (final type in noteTypes)
                if (counts[type]! > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${counts[type]}',
                        style: TextStyle(
                          color: t.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(width: 5),
                      TypeMark(type),
                    ],
                  ),
            ],
          ),
          section(l.dashActivity, _ActivityMap(entries: all, now: now)),
          section(
            l.dashByType,
            Column(
              children: [
                for (final type in noteTypes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(
                            typeFilterLabel(l, type),
                            style: TextStyle(color: t.ink2, fontSize: 14),
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, c) => Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                height: 14,
                                width: maxCount == 0
                                    ? 0
                                    : c.maxWidth * counts[type]! / maxCount,
                                decoration: BoxDecoration(
                                  color: strongColor(t, type),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${counts[type]}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: t.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          section(
            l.dashTopTags,
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in diary.topTags(5, all))
                  ActionChip(
                    label: Text(
                      '#$tag  ${all.where((e) => e.tags.contains(tag)).length}',
                    ),
                    onPressed: () => diary.setTag(tag),
                  ),
              ],
            ),
          ),
          if (errors.isNotEmpty)
            section(
              l.dashLastErrors,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in errors) _ErrorLink(entry: e, now: now),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _ErrorLink extends StatelessWidget {
  const _ErrorLink({required this.entry, required this.now});
  final DiaryEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final created = localTime(entry.createdAt);
    return Tappable(
      onTap: () => DevDiaryScope.of(context).diary.open(entry.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                entry.title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: t.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: t.primary,
                ),
              ),
            ),
            if (created != null) ...[
              const SizedBox(width: 10),
              Text(
                italianDate(created, now),
                style: TextStyle(color: t.ink3, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityMap extends StatelessWidget {
  const _ActivityMap({required this.entries, required this.now});
  final List<DiaryEntry> entries;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final grid = activityGrid(entries, now);
    final start = activityStart(now);
    Color cell(int level) => level == 0
        ? t.ruleStrong.withValues(alpha: .25)
        : t.primary.withValues(alpha: const [0.0, .3, .55, .8, 1.0][level]);
    const size = 13.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Su schermi stretti si vede subito la parte più recente.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            children: [
              for (var w = 0; w < grid.length; w++)
                Tooltip(
                  message: l.activityTooltip(
                    italianDate(start.add(Duration(days: w * 7)), now),
                    grid[w].fold(0, (a, b) => a + b),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Column(
                      children: [
                        for (final n in grid[w])
                          Container(
                            width: size,
                            height: size,
                            margin: const EdgeInsets.only(bottom: 3),
                            decoration: BoxDecoration(
                              color: cell(activityLevel(n)),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.dashLess, style: TextStyle(color: t.ink3, fontSize: 12.5)),
            const SizedBox(width: 6),
            for (var level = 0; level <= 4; level++)
              Container(
                width: size,
                height: size,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                  color: cell(level),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 3),
            Text(l.dashMore, style: TextStyle(color: t.ink3, fontSize: 12.5)),
          ],
        ),
      ],
    );
  }
}
