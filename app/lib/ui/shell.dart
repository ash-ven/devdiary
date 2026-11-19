import 'package:material_ui/material_ui.dart';

import '../state/diary_store.dart';
import '../state/scope.dart';
import 'common.dart';
import 'diary_list.dart';
import 'note_sheet.dart';

/// Guscio responsivo: tre colonne da 1180px, menu a icone da 820px, una colonna sotto.
class DevDiaryShell extends StatelessWidget {
  const DevDiaryShell({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = DevDiaryScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([scope.diary, scope.settings]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final diary = scope.diary;
          final listy =
              diary.view == DiaryView.diary ||
              diary.view == DiaryView.favorites ||
              diary.view == DiaryView.trash;
          if (w < 820) return _Narrow(listy: listy);
          final wide = w >= 1180;
          return Scaffold(
            body: NotebookPaper(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: wide ? 236 : 76,
                    child: SideMenu(compact: !wide),
                  ),
                  _rule(context),
                  if (listy) ...[
                    SizedBox(width: wide ? 396 : 340, child: const DiaryList()),
                    _rule(context),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 22, 0),
                        child: _SheetArea(),
                      ),
                    ),
                  ] else
                    const Expanded(child: _ComingSoon()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _rule(BuildContext context) => VerticalDivider(
    width: 1,
    color: context.tokens.ruleStrong.withValues(alpha: .35),
  );
}

class _SheetArea extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final entry = DevDiaryScope.of(context).diary.selected;
    if (entry == null) {
      return Center(
        child: Text(
          context.l10n.pickNote,
          style: TextStyle(color: context.tokens.ink3, fontSize: 15),
        ),
      );
    }
    return NoteSheet(key: ValueKey(entry.id), entry: entry);
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      context.l10n.comingSoon,
      style: TextStyle(color: context.tokens.ink2, fontSize: 16),
    ),
  );
}

class _Narrow extends StatelessWidget {
  const _Narrow({required this.listy});
  final bool listy;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final diary = DevDiaryScope.of(context).diary;
    final entry = listy ? diary.selected : null;
    return Scaffold(
      drawer: Drawer(
        backgroundColor: t.paper,
        child: const SafeArea(child: SideMenu(compact: false, inDrawer: true)),
      ),
      appBar: AppBar(
        backgroundColor: t.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: t.ink,
        leading: entry != null
            ? IconButton(
                tooltip: l.back,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => diary.select(null),
              )
            : Builder(
                builder: (context) => IconButton(
                  tooltip: l.openMenu,
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/devdiary_logo.png',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 8),
            Text(
              l.appTitle,
              style: TextStyle(fontWeight: FontWeight.w800, color: t.ink),
            ),
          ],
        ),
      ),
      body: NotebookPaper(
        child: !listy
            ? const _ComingSoon()
            : entry != null
            ? Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: NoteSheet(
                  key: ValueKey(entry.id),
                  entry: entry,
                  narrow: true,
                ),
              )
            : const DiaryList(),
      ),
    );
  }
}

/// Menu laterale: logo, viste, tag più usati, stato dell'API, tema.
class SideMenu extends StatelessWidget {
  const SideMenu({super.key, required this.compact, this.inDrawer = false});
  final bool compact;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final scope = DevDiaryScope.of(context);
    final diary = scope.diary;
    final settings = scope.settings;

    void go(DiaryView v) {
      diary.setView(v);
      if (inDrawer) Navigator.of(context).pop();
    }

    final items = [
      (DiaryView.diary, Icons.menu_book_outlined, l.navDiary),
      (DiaryView.favorites, Icons.star_border, l.navFavorites),
      (DiaryView.dashboard, Icons.insights_outlined, l.navDashboard),
      (DiaryView.trash, Icons.delete_outline, l.navTrash),
      (DiaryView.settings, Icons.settings_outlined, l.navSettings),
    ];

    final online = diary.apiOnline;
    final statusText = online == null
        ? l.apiChecking
        : online
        ? l.apiOnline
        : l.apiOffline;
    final statusColor = online == null
        ? t.ink3
        : online
        ? t.ok
        : t.accentText;

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 8 : 14, 20, compact ? 8 : 14, 14),
      child: Column(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: compact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Image.asset(
                'assets/images/devdiary_logo.png',
                width: 42,
                height: 42,
                semanticLabel: compact ? l.appTitle : null,
              ),
              if (!compact) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.appTitle,
                        style: TextStyle(
                          color: t.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.4,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l.appSubtitle,
                        style: TextStyle(color: t.ink3, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 22),
          for (final (view, icon, label) in items)
            Tooltip(
              message: compact ? label : '',
              child: Tappable(
                onTap: () => go(view),
                selected: diary.view == view,
                semanticLabel: compact ? label : null,
                radius: 8,
                color: diary.view == view ? t.sheet : null,
                shadow: diary.view == view ? sheetShadow(t) : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 10,
                    vertical: 9,
                  ),
                  child: Row(
                    mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                    children: [
                      Icon(
                        icon,
                        size: 19,
                        color: diary.view == view ? t.ink : t.ink2,
                      ),
                      if (!compact) ...[
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: diary.view == view ? t.ink : t.ink2,
                              fontSize: 15,
                              fontWeight: diary.view == view
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (!compact && diary.topTags().isNotEmpty) ...[
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 6),
              child: Text(
                l.tagsTitle,
                style: TextStyle(
                  color: t.ink3,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                for (final tag in diary.topTags())
                  Tappable(
                    radius: 99,
                    onTap: () {
                      diary.setTag(tag);
                      if (inDrawer) Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: t.ruleStrong),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(color: t.ink2, fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const Spacer(),
          Semantics(
            liveRegion: true,
            child: Tooltip(
              message: compact ? statusText : '',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.ruleStrong.withValues(alpha: .5)),
                ),
                child: Row(
                  mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          statusText,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: t.ink2, fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (compact)
            IconButton(
              tooltip: l.themeLabel,
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                color: t.ink2,
              ),
              onPressed: () => settings.setThemeMode(
                Theme.of(context).brightness == Brightness.dark
                    ? ThemeMode.light
                    : ThemeMode.dark,
              ),
            )
          else
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                foregroundColor: t.ink2,
                selectedForegroundColor: t.ink,
                selectedBackgroundColor: t.sheet,
                side: BorderSide(color: t.ruleStrong),
                textStyle: const TextStyle(fontSize: 12.5),
                visualDensity: VisualDensity.compact,
              ),
              segments: [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l.themeLight),
                ),
                ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark)),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l.themeSystem),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
        ],
      ),
    );
  }
}
