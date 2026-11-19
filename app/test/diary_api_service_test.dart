import 'dart:convert';

import 'package:dev_diary/models/diary_entry.dart';
import 'package:dev_diary/services/api_exception.dart';
import 'package:dev_diary/services/diary_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const hex = '6afeb4a37ab5376904d214ad';

DiaryEntry entry() => DiaryEntry(
      id: hex,
      title: 'Titolo',
      content: 'Contenuto',
      type: 'note',
      tags: const ['a'],
      isFavorite: false,
      createdAt: '2026-11-19T08:00:00.000Z',
      updatedAt: '2026-11-19T08:00:00.000Z',
    );

http.Response jsonResponse(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  test('builds urls without double slashes', () async {
    final requested = <Uri>[];
    final service = DiaryApiService(
      baseUrl: 'https://a.example/webhook/',
      client: MockClient((req) async {
        requested.add(req.url);
        return jsonResponse([], 200);
      }),
    );
    await service.getEntries();
    expect(requested.single.toString(), 'https://a.example/webhook/diary');
  });

  test('parses string ids from the new api', () async {
    final service = DiaryApiService(
      baseUrl: 'https://a.example/webhook',
      client: MockClient((req) async => jsonResponse([
            {
              '_id': hex,
              'title': 'perché più ✓',
              'content': 'C',
              'type': 'idea',
              'tags': ['x'],
              'isFavorite': true,
              'isSample': true,
              'deletedAt': null,
              'createdAt': '2026-11-19T08:00:00.000Z',
              'updatedAt': '2026-11-19T08:00:00.000Z',
            }
          ], 200)),
    );
    final list = await service.getEntries();
    expect(list.single.id, hex);
    expect(list.single.title, 'perché più ✓');
  });

  test('exposes the api error message', () async {
    final service = DiaryApiService(
      baseUrl: 'https://a.example/webhook',
      client: MockClient((req) async => jsonResponse({
            'error': true,
            'code': 'SAMPLE_READ_ONLY',
            'message': 'Le note di esempio non si modificano: creane una tua per provare',
          }, 403)),
    );
    await expectLater(
      service.updateEntry(entry()),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 403)
          .having((e) => e.code, 'code', 'SAMPLE_READ_ONLY')
          .having((e) => e.toString(), 'toString', 'Le note di esempio non si modificano: creane una tua per provare')),
    );
  });

  test('handles non-json error bodies', () async {
    final service = DiaryApiService(
      baseUrl: 'https://a.example/webhook',
      client: MockClient((req) async => http.Response('<html>Bad gateway</html>', 502)),
    );
    await expectLater(
      service.getEntries(),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 502)
          .having((e) => e.code, 'code', 'HTTP_502')
          .having((e) => e.message, 'message', 'Il server ha risposto con un errore (502). Riprova tra poco.')),
    );
  });

  test('times out slow responses', () async {
    final service = DiaryApiService(
      baseUrl: 'https://a.example/webhook',
      timeout: const Duration(milliseconds: 50),
      client: MockClient((req) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return jsonResponse([], 200);
      }),
    );
    await expectLater(
      service.getEntries(),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'TIMEOUT')),
    );
  });

  test('reports network failures', () async {
    final service = DiaryApiService(
      baseUrl: 'https://a.example/webhook',
      client: MockClient((req) async => throw http.ClientException('connessione rifiutata')),
    );
    await expectLater(
      service.getStatus(),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'NETWORK')
          .having((e) => e.message, 'message', 'Impossibile raggiungere il server.')),
    );
  });

  test('uses the default client when none is given', () async {
    var called = false;
    DiaryApiService.defaultClient = MockClient((req) async {
      called = true;
      return jsonResponse({'status': 'OK', 'database': 'OK'}, 200);
    });
    addTearDown(() => DiaryApiService.defaultClient = null);
    expect(await DiaryApiService(baseUrl: 'https://a.example/webhook').getStatus(), 'OK');
    expect(called, isTrue);
  });
}
