import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'services/diary_api_service.dart';
import 'services/visitor_id.dart';
import 'state/diary_store.dart';
import 'state/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  DiaryApiService.defaultVisitorId = await VisitorStore().load();
  final settings = SettingsStore();
  await settings.load();
  final diary = DiaryStore(DiaryApiService());
  runApp(DevDiaryApp(diary: diary, settings: settings));
  diary.checkStatus();
  diary.load();
}
