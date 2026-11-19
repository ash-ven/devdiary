import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_config.dart';
import '../state/scope.dart';
import 'common.dart';

const repoUrl = 'https://github.com/ash-ven/devdiary';
const readmeUrl = 'https://github.com/ash-ven/devdiary#readme';

/// Impostazioni: tema, API, identificativo anonimo, link al codice.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = context.l10n;
    final scope = DevDiaryScope.of(context);
    final online = scope.diary.apiOnline;

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 26),
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
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
    final body = TextStyle(color: t.ink2, fontSize: 15, height: 1.5);

    Widget link(String label, String url) => TextButton.icon(
      onPressed: () => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: t.primary,
        minimumSize: const Size(44, 44),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.navSettings,
                  style: TextStyle(
                    color: t.ink,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                section(l.themeLabel, [
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      foregroundColor: t.ink2,
                      selectedForegroundColor: t.ink,
                      selectedBackgroundColor: t.sheet,
                      side: BorderSide(color: t.ruleStrong),
                    ),
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(l.themeLight),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(l.themeDark),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(l.themeSystem),
                      ),
                    ],
                    selected: {scope.settings.themeMode},
                    onSelectionChanged: (s) =>
                        scope.settings.setThemeMode(s.first),
                  ),
                ]),
                section(l.settingsApi, [
                  Text('${l.settingsApiAddress}: $apiBaseUrl', style: body),
                  const SizedBox(height: 4),
                  Text(
                    online == null
                        ? l.apiChecking
                        : online
                        ? l.apiOnline
                        : l.apiOffline,
                    style: body,
                  ),
                ]),
                section(l.settingsVisitor, [
                  Text(l.settingsVisitorBody, style: body),
                ]),
                section(l.settingsCode, [
                  link(l.repoLink, repoUrl),
                  link(l.readmeLink, readmeUrl),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
