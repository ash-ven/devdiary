import 'dart:convert';

import 'package:dev_diary/app.dart';
import 'package:dev_diary/services/diary_api_service.dart';
import 'package:dev_diary/state/diary_store.dart';
import 'package:dev_diary/state/settings_store.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _notes = [
  {
    '_id': 'a1',
    'title': 'n8n restituisce _id come {buffer}',
    'content': '## Problema\n\nIl **dettaglio** falliva.\n\n- uno\n- due',
    'type': 'errore',
    'language': 'javascript',
    'code': 'const x = 1; // prova',
    'tags': ['n8n', 'mongodb'],
    'isFavorite': true,
    'isSample': true,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'updatedAt': DateTime.now().toUtc().toIso8601String(),
  },
];

Future<DiaryStore> _pump(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final client = MockClient((r) async {
    if (r.url.path.endsWith('/status')) {
      return http.Response(jsonEncode({'status': 'ok', 'database': 'ok'}), 200);
    }
    return http.Response(jsonEncode(_notes), 200);
  });
  final diary = DiaryStore(
    DiaryApiService(client: client, baseUrl: 'http://x'),
  );
  await tester.pumpWidget(DevDiaryApp(diary: diary, settings: SettingsStore()));
  await diary.load();
  await tester.pumpAndSettle();
  return diary;
}

void main() {
  testWidgets('three columns at 1280 show the list and the open note', (
    tester,
  ) async {
    final diary = await _pump(tester, const Size(1280, 900));
    expect(find.text('Oggi'), findsOneWidget);
    await tester.tap(find.text('n8n restituisce _id come {buffer}'));
    await tester.pumpAndSettle();
    expect(diary.selectedId, 'a1');
    expect(find.text('Problema'), findsOneWidget);
    expect(find.text('Copia'), findsOneWidget);
  });

  testWidgets('single column at 600 navigates to the note and back', (
    tester,
  ) async {
    final diary = await _pump(tester, const Size(600, 900));
    await tester.tap(find.text('n8n restituisce _id come {buffer}'));
    await tester.pumpAndSettle();
    expect(find.text('Problema'), findsOneWidget);
    await tester.tap(find.byTooltip('Torna al diario'));
    await tester.pumpAndSettle();
    expect(diary.selectedId, isNull);
    expect(find.text('Oggi'), findsOneWidget);
  });

  testWidgets('new note opens in the diary without filters', (tester) async {
    final diary = await _pump(tester, const Size(1280, 900));
    diary.setView(DiaryView.favorites);
    diary.searchField.text = 'prima';
    diary.setSearch('prima');
    diary.startNew();
    await tester.pumpAndSettle();
    expect(diary.view, DiaryView.diary);
    expect(diary.search, isEmpty);
    expect(diary.searchField.text, isEmpty);
    expect(find.text('Nuova nota'), findsWidgets);
  });

  test('start retries until the api answers, then loads the diary', () async {
    var statusCalls = 0;
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/status')) {
        statusCalls++;
        return statusCalls < 3
            ? http.Response('{"code":"DATABASE_UNAVAILABLE"}', 503)
            : http.Response(
                jsonEncode({'status': 'OK', 'database': 'OK'}),
                200,
              );
      }
      return http.Response(jsonEncode(_notes), 200);
    });
    final diary = DiaryStore(
      DiaryApiService(client: client, baseUrl: 'http://x'),
      wakeDelays: const [0],
    );
    await diary.start();
    expect(statusCalls, 3);
    expect(diary.waking, isFalse);
    expect(diary.entries.length, 1);
  });

  test('start gives up after the limit and offers retry', () async {
    final client = MockClient((r) async => http.Response('{}', 503));
    final diary = DiaryStore(
      DiaryApiService(client: client, baseUrl: 'http://x'),
      wakeDelays: const [0],
      wakeLimit: Duration.zero,
    );
    await diary.start();
    expect(diary.waking, isTrue);
    expect(diary.gaveUp, isTrue);
  });
}
