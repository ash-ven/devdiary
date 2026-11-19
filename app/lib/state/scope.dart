import 'package:material_ui/material_ui.dart';

import '../services/request_log.dart';
import 'diary_store.dart';
import 'settings_store.dart';

/// Rende disponibili gli store a tutto l'albero dei widget: chi lo legge
/// con [of] si ricostruisce a ogni cambiamento del diario o delle preferenze.
class DevDiaryScope extends InheritedNotifier<Listenable> {
  DevDiaryScope({
    super.key,
    required this.diary,
    required this.settings,
    required this.log,
    required super.child,
  }) : super(notifier: Listenable.merge([diary, settings]));

  final DiaryStore diary;
  final SettingsStore settings;
  final RequestLog log;

  static DevDiaryScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DevDiaryScope>()!;
}
