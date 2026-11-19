import 'package:material_ui/material_ui.dart';

import 'l10n/app_localizations.dart';
import 'services/request_log.dart';
import 'state/diary_store.dart';
import 'state/scope.dart';
import 'state/settings_store.dart';
import 'theme/devdiary_theme.dart';
import 'ui/shell.dart';

class DevDiaryApp extends StatelessWidget {
  const DevDiaryApp({super.key, required this.diary, required this.settings});

  final DiaryStore diary;
  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    return DevDiaryScope(
      diary: diary,
      settings: settings,
      log: RequestLog.shared,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          title: 'DevDiary',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: settings.themeMode,
          locale: const Locale('it'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DevDiaryShell(),
        ),
      ),
    );
  }
}
