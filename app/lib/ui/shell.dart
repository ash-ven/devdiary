import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../state/diary_store.dart';
import '../state/scope.dart';
import 'command_palette.dart';
import 'common.dart';
import 'dashboard_view.dart';
import 'diary_list.dart';
import 'note_form.dart';
import 'note_sheet.dart';
import 'request_panel.dart';
import 'settings_view.dart';
import 'wake_screen.dart';

/// Guscio responsivo: tre colonne da 1180px, menu a icone da 820px, una colonna sotto.
/// Ctrl K (Cmd K su Mac) apre la ricerca rapida.
class DevDiaryShell extends StatelessWidget {
  const DevDiaryShell({super.key});

  @override
  Widget build(BuildContext context) {
    final diary = DevDiaryScope.of(context).diary;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            showCommandPalette(context),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            showCommandPalette(context),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            if (w < 820) return const _Narrow();
            final wide = w >= 1180;
            final Widget center;
            if (diary.apiOnline == false) {
              center = const Expanded(child: WakeScreen());
            } else if (diary.isListView) {
              center = Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: wide ? 396 : 340, child: const DiaryList()),
                    _rule(context),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(18, 18, 22, 0),
                              child: _SheetArea(),
                            ),
                          ),
                          RequestPanel(initiallyOpen: wide),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            } else {
              center = Expanded(
                child: diary.view == DiaryView.dashboard
                    ? const DashboardView()
                    : const SettingsView(),
              );
            }
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
                    center,
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static Widget _rule(BuildContext context) => VerticalDivider(
    width: 1,
    color: context.tokens.ruleStrong.withValues(alpha: .35),
  );
}

class _SheetArea extends StatelessWidget {
  const _SheetArea();

  @override
  Widget build(BuildContext context) {
    final diary = DevDiaryScope.of(context).diary;
    if (diary.composing) {
      return NoteForm(key: ValueKey(diary.editing?.id), entry: diary.editing);
    }
    final entry = diary.selected;
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

class _Narrow extends StatelessWidget {
  const _Narrow();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final diary = DevDiaryScope.of(context).diary;
    final entry = diary.isListView ? diary.selected : null;
    final inside = diary.composing || entry != null;

    final Widget body;
    if (diary.apiOnline == false) {
      body = const WakeScreen();
    } else if (diary.composing) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: NoteForm(
          key: ValueKey(diary.editing?.id),
          entry: diary.editing,
          narrow: true,
        ),
      );
    } else if (entry != null) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: NoteSheet(key: ValueKey(entry.id), entry: entry, narrow: true),
      );
    } else if (diary.view == DiaryView.dashboard) {
      body = const DashboardView();
    } else if (diary.view == DiaryView.settings) {
      body = const SettingsView();
    } else {
      body = const DiaryList();
    }

    return Scaffold(
      drawer: Drawer(
        backgroundColor: t.paper,
        child: const SafeArea(child: SideMenu(compact: false, inDrawer: true)),
      ),
      appBar: AppBar(
        backgroundColor: t.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: t.ink,
        leading: inside
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
      floatingActionButton:
          !inside && diary.view == DiaryView.diary && diary.apiOnline != false
          ? FloatingActionButton.extended(
              onPressed: diary.startNew,
              backgroundColor: t.primary,
              foregroundColor: t.onPrimary,
              icon: const Icon(Icons.add),
              label: Text(l.newNote),
            )
          : null,
      body: NotebookPaper(child: body),
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

    Widget navItem(DiaryView view, IconData icon, String label) {
      final on = diary.view == view;
      return Tooltip(
        message: compact ? label : '',
        child: Tappable(
          onTap: () => go(view),
          selected: on,
          semanticLabel: compact ? label : null,
          radius: 8,
          color: on ? t.sheet : null,
          shadow: on ? sheetShadow(t) : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 10,
              vertical: 9,
            ),
            child: Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Icon(icon, size: 19, color: on ? t.ink : t.ink2),
                if (!compact) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: on ? t.ink : t.ink2,
                        fontSize: 15,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

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
          for (final (view, icon, label) in items) navItem(view, icon, label),
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
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                l.paletteShortcut,
                style: TextStyle(color: t.ink3, fontSize: 12.5),
              ),
            ),
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
                padding: const EdgeInsets.symmetric(horizontal: 4),
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
                  label: Text(l.themeAuto),
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
