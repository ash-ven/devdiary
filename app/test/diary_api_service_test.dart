import 'dart:async';
import 'dart:convert';

import 'package:dev_diary/models/diary_entry.dart';
import 'package:dev_diary/services/api_exception.dart';
import 'package:dev_diary/services/diary_api_service.dart';
import 'package:dev_diary/services/request_log.dart';
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
      client: MockClient(
        (req) async => jsonResponse([
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
          },
        ], 200),
      ),
    );
    final list = await service.getEntries();
    expect(list.single.id, hex);
    expect(list.single.title, 'perché più ✓');
  });

  test('exposes the api error message', () async {
    final service = DiaryApiService(
      baseUrl: 'https://a.example/webhook',
      client: MockClient(
        (req) async => jsonResponse({
          'error': true,
          'code': 'SAMPLE_READ_ONLY',
          'message':
              'Le note di esempio non si modificano: creane una tua per provare',
        }, 403),
      ),
    );
    await expectLater(
      service.updateEntry(entry()),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.code, 'code', 'SAMPLE_READ_ONLY')
            .having(
              (e) => e.toString(),
              'toString',
              'Le note di esempio non si modificano: creane una tua per provare',
            ),
      ),
    );
  });

  test('handles non-json error bodies', () async {
    final service = DiaryApiService(
      baseUrl: 'https://a.example/webhook',
      client: MockClient(
        (req) async => http.Response('<html>Bad gateway</html>', 502),
      ),
    );
    await expectLater(
      service.getEntries(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 502)
            .having((e) => e.code, 'code', 'HTTP_502')
            .having(
              (e) => e.message,
              'message',
              'Il server ha risposto con un errore (502). Riprova tra poco.',
            ),
      ),
    );
  });

  test('reports network failures', () async {
    final service = DiaryApiService(
      baseUrl: 'https://a.example/webhook',
      client: MockClient(
        (req) async => throw http.ClientException('connessione rifiutata'),
      ),
    );
    await expectLater(
      service.getStatus(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'NETWORK')
            .having(
              (e) => e.message,
              'message',
              'Impossibile raggiungere il server.',
            ),
      ),
    );
  });

  test('uses the default client when none is given', () async {
    var called = false;
    DiaryApiService.defaultClient = MockClient((req) async {
      called = true;
      return jsonResponse({'status': 'OK', 'database': 'OK'}, 200);
    });
    addTearDown(() => DiaryApiService.defaultClient = null);
    expect(
      (await DiaryApiService(
        baseUrl: 'https://a.example/webhook',
        log: RequestLog(),
      ).getStatus()).databaseOk,
      isTrue,
    );
    expect(called, isTrue);
  });

  group('log, trash and robustness', () {
    const base = 'https://a.example/webhook';

    test('logs every request with status and duration', () async {
      final log = RequestLog();
      final service = DiaryApiService(
        baseUrl: base,
        log: log,
        client: MockClient((req) async {
          if (req.url.path.endsWith('/status')) {
            throw http.ClientException('giù');
          }
          return jsonResponse([], 200);
        }),
      );
      await service.getEntries(trash: true);
      await expectLater(service.getStatus(), throwsA(isA<ApiException>()));
      expect(log.records, hasLength(2));
      expect(log.records[1].method, 'GET');
      expect(log.records[1].pathAndQuery, '/diary?trash=true');
      expect(log.records[1].status, 200);
      expect(log.records[1].durationMs, greaterThanOrEqualTo(0));
      expect(log.records[0].pathAndQuery, '/status');
      expect(log.records[0].status, 0);
    });

    test('aborts the request on timeout', () async {
      var aborted = false;
      final service = DiaryApiService(
        baseUrl: base,
        log: RequestLog(),
        timeout: const Duration(milliseconds: 50),
        client: MockClient.streaming((req, body) async {
          final trigger = (req as http.Abortable).abortTrigger!;
          try {
            await trigger.timeout(const Duration(seconds: 2));
          } on TimeoutException {
            return http.StreamedResponse(const Stream.empty(), 200);
          }
          aborted = true;
          throw http.RequestAbortedException(req.url);
        }),
      );
      await expectLater(
        service.getEntries(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'TIMEOUT')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(aborted, isTrue);
    });

    test('non-json success becomes FORMAT', () async {
      final service = DiaryApiService(
        baseUrl: base,
        log: RequestLog(),
        client: MockClient((req) async => http.Response('<html>', 200)),
      );
      await expectLater(
        service.getEntries(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 200)
              .having((e) => e.code, 'code', 'FORMAT'),
        ),
      );
    });

    test('numeric error codes fall back to HTTP status', () async {
      final service = DiaryApiService(
        baseUrl: base,
        log: RequestLog(),
        client: MockClient(
          (req) async => jsonResponse({'code': 42, 'message': 'boh'}, 500),
        ),
      );
      await expectLater(
        service.getEntries(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'HTTP_500')),
      );
    });

    test('restore and permanent delete call the right urls', () async {
      final calls = <String>[];
      final service = DiaryApiService(
        baseUrl: base,
        log: RequestLog(),
        client: MockClient((req) async {
          calls.add('${req.method} ${req.url}');
          return jsonResponse({'success': true}, 200);
        }),
      );
      await service.restoreEntry(hex);
      await service.deleteEntry(hex, permanent: true);
      await service.deleteEntry(hex);
      expect(calls, [
        'POST $base/diary/restore?id=$hex',
        'DELETE $base/diary?id=$hex&permanent=true',
        'DELETE $base/diary?id=$hex',
      ]);
    });

    test('createEntry returns the id and export returns markdown', () async {
      final service = DiaryApiService(
        baseUrl: base,
        log: RequestLog(),
        client: MockClient((req) async {
          if (req.url.path.endsWith('/export/markdown')) {
            return http.Response(
              '# DevDiary Export',
              200,
              headers: {'content-type': 'text/markdown; charset=utf-8'},
            );
          }
          return jsonResponse({'success': true, '_id': hex}, 201);
        }),
      );
      expect(await service.createEntry(entry()), hex);
      expect(await service.exportMarkdown(), '# DevDiary Export');
    });

    test('parses isSample and deletedAt', () {
      final e = DiaryEntry.fromJson({
        '_id': hex,
        'isSample': true,
        'deletedAt': '2026-11-19T09:00:00.000Z',
      });
      expect(e.isSample, isTrue);
      expect(e.deletedAt, '2026-11-19T09:00:00.000Z');
      final f = DiaryEntry.fromJson({'_id': hex});
      expect(f.isSample, isFalse);
      expect(f.deletedAt, isNull);
    });
  });
}
