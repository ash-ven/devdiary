import 'dart:convert';

import 'package:dev_diary/models/diary_entry.dart';
import 'package:dev_diary/services/diary_api_service.dart';
import 'package:dev_diary/services/visitor_id.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  test('generates uuid v4', () {
    final ids = List.generate(100, (_) => generateVisitorId());
    for (final id in ids) {
      expect(uuidV4.hasMatch(id), isTrue, reason: id);
    }
    expect(ids.toSet().length, 100);
  });

  test('keeps the same id across loads', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await VisitorStore().load();
    final second = await VisitorStore().load();
    expect(uuidV4.hasMatch(first), isTrue);
    expect(second, first);
    expect(
      (await SharedPreferences.getInstance()).getString(VisitorStore.key),
      first,
    );
  });

  test('replaces a malformed stored id', () async {
    SharedPreferences.setMockInitialValues({VisitorStore.key: 'abc'});
    final id = await VisitorStore().load();
    expect(uuidV4.hasMatch(id), isTrue);
  });

  test('falls back to memory when storage fails', () async {
    final store = VisitorStore(
      prefs: () async => throw Exception('archiviazione bloccata'),
    );
    final first = await store.load();
    final second = await store.load();
    expect(uuidV4.hasMatch(first), isTrue);
    expect(second, first);
  });

  test('sends the visitor header', () async {
    const visitor = '3f1c2a9e-5b7d-4c8e-9a1f-2b3c4d5e6f70';
    final seen = <String?>[];
    final service = DiaryApiService(
      baseUrl: 'https://a.example/webhook',
      visitorId: visitor,
      client: MockClient((req) async {
        seen.add(req.headers['X-Demo-Visitor']);
        final body = req.method == 'GET' ? '[]' : '{"success":true}';
        return http.Response(
          body,
          req.method == 'POST' ? 201 : 200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final entry = DiaryEntry(
      id: '6afeb4a37ab5376904d214ad',
      title: 'T',
      content: 'C',
      type: 'note',
      tags: const [],
      isFavorite: false,
      createdAt: '',
      updatedAt: '',
    );
    await service.getEntries();
    await service.createEntry(entry);
    await service.updateEntry(entry);
    await service.deleteEntry(entry.id);
    expect(seen, List.filled(4, visitor));
    expect(jsonEncode(seen), isNot(contains('null')));
  });

  test('uses the default visitor id', () {
    DiaryApiService.defaultVisitorId = 'abc';
    addTearDown(() => DiaryApiService.defaultVisitorId = null);
    expect(
      DiaryApiService(baseUrl: 'https://a.example/webhook').visitorId,
      'abc',
    );
  });
}
