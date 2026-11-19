import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/diary_entry.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'request_log.dart';

/// Esito di GET /status.
class ApiStatus {
  const ApiStatus({required this.databaseOk});

  final bool databaseOk;
}

class DiaryApiService {
  DiaryApiService({
    http.Client? client,
    String? baseUrl,
    String? visitorId,
    this.timeout = const Duration(seconds: 30),
    this.statusTimeout,
    RequestLog? log,
  }) : _client = client ?? defaultClient ?? http.Client(),
       baseUrl = normalizeBaseUrl(baseUrl ?? apiBaseUrl),
       visitorId = visitorId ?? defaultVisitorId,
       _log = log ?? RequestLog.shared;

  /// Client condiviso: i test lo sostituiscono con un MockClient.
  static http.Client? defaultClient;

  /// Identificativo anonimo del visitatore della demo, impostato all'avvio.
  static String? defaultVisitorId;

  static const _timeoutMessage =
      'Il server non risponde: potrebbe essere in avvio, riprova tra un minuto.';

  final http.Client _client;
  final String baseUrl;
  final String? visitorId;
  final Duration timeout;

  /// Timeout più breve usato solo da getStatus (se nullo vale [timeout]).
  final Duration? statusTimeout;
  final RequestLog _log;

  Map<String, String> _headers({bool json = false}) => {
    if (json) 'Content-Type': 'application/json',
    'X-Demo-Visitor': ?visitorId,
  };

  /// Esegue una richiesta, la registra nel log e trasforma timeout, errori di
  /// rete e risposte d'errore in ApiException. Allo scadere del timeout la
  /// richiesta viene davvero annullata.
  Future<http.Response> _send(
    String method,
    Uri uri, {
    bool json = false,
    String? body,
    Duration? limit,
  }) async {
    final started = DateTime.now();
    final stopwatch = Stopwatch()..start();
    var status = 0;
    final abort = Completer<void>();
    final timer = Timer(limit ?? timeout, abort.complete);
    try {
      final request = http.AbortableRequest(
        method,
        uri,
        abortTrigger: abort.future,
      )..headers.addAll(_headers(json: json));
      if (body != null) request.body = body;
      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);
      status = response.statusCode;
      if (status >= 200 && status < 300) return response;
      throw _errorFrom(response);
    } on http.ClientException {
      if (abort.isCompleted) {
        throw const ApiException(0, 'TIMEOUT', _timeoutMessage);
      }
      throw const ApiException(
        0,
        'NETWORK',
        'Impossibile raggiungere il server.',
      );
    } finally {
      timer.cancel();
      _log.add(
        RequestRecord(
          method: method,
          pathAndQuery: uri.toString().substring(baseUrl.length),
          status: status,
          durationMs: stopwatch.elapsedMilliseconds,
          at: started,
        ),
      );
    }
  }

  ApiException _errorFrom(http.Response response) {
    final status = response.statusCode;
    try {
      final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map<String, dynamic> && data['message'] is String) {
        final code = data['code'];
        return ApiException(
          status,
          code is String && code.isNotEmpty ? code : 'HTTP_$status',
          data['message'] as String,
        );
      }
    } on FormatException {
      // corpo non JSON (es. pagina HTML del proxy di Render)
    }
    return ApiException(
      status,
      'HTTP_$status',
      'Il server ha risposto con un errore ($status). Riprova tra poco.',
    );
  }

  /// Decodifica un corpo 2xx; se non è JSON valido lancia ApiException FORMAT.
  dynamic _json(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(
        response.statusCode,
        'FORMAT',
        'Formato della risposta non valido',
      );
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse(
    '$baseUrl$path',
  ).replace(queryParameters: query == null || query.isEmpty ? null : query);

  // GET STATUS
  Future<ApiStatus> getStatus() async {
    final response = await _send(
      'GET',
      _uri('/status'),
      limit: statusTimeout ?? timeout,
    );
    final dynamic data = _json(response);
    return ApiStatus(
      databaseOk: data is Map && data['database']?.toString() == 'OK',
    );
  }

  // GET NOTE CON FILTRI OPZIONALI (trash: elenca il cestino)
  Future<List<DiaryEntry>> getEntries({
    String? type,
    bool? favorite,
    String? tag,
    String? search,
    bool trash = false,
  }) async {
    final uri = _uri('/diary', {
      if (type != null && type.isNotEmpty) 'type': type,
      if (favorite != null) 'favorite': favorite.toString(),
      if (tag != null && tag.isNotEmpty) 'tag': tag,
      if (search != null && search.isNotEmpty) 'search': search,
      if (trash) 'trash': 'true',
    });
    final response = await _send('GET', uri);
    final dynamic data = _json(response);
    if (data is List) {
      return data
          .map(
            (item) =>
                DiaryEntry.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    }
    if (data is Map<String, dynamic>) return [DiaryEntry.fromJson(data)];
    throw const ApiException(
      200,
      'FORMAT',
      'Formato della risposta non valido',
    );
  }

  // GET NOTA PER ID
  Future<DiaryEntry> getEntryById(String id, {bool trash = false}) async {
    final uri = _uri('/diary/detail', {'id': id, if (trash) 'trash': 'true'});
    final response = await _send('GET', uri);
    final dynamic data = _json(response);
    if (data is Map<String, dynamic>) return DiaryEntry.fromJson(data);
    throw const ApiException(200, 'FORMAT', 'Formato della nota non valido');
  }

  // CREA NOTA: restituisce l'_id della nota creata
  Future<String> createEntry(DiaryEntry entry) async {
    final response = await _send(
      'POST',
      _uri('/diary'),
      json: true,
      body: jsonEncode(entry.toJson()),
    );
    final dynamic data = _json(response);
    final id = data is Map ? data['_id'] : null;
    if (id is String && id.isNotEmpty) return id;
    throw ApiException(
      response.statusCode,
      'FORMAT',
      'Formato della risposta non valido',
    );
  }

  // MODIFICA NOTA
  Future<void> updateEntry(DiaryEntry entry) async {
    await _send(
      'PUT',
      _uri('/diary', {'id': entry.id}),
      json: true,
      body: jsonEncode(entry.toJson()),
    );
  }

  // ELIMINA NOTA (nel cestino; con permanent la cancella per sempre)
  Future<void> deleteEntry(String id, {bool permanent = false}) async {
    await _send(
      'DELETE',
      _uri('/diary', {'id': id, if (permanent) 'permanent': 'true'}),
    );
  }

  // RIPRISTINA NOTA DAL CESTINO
  Future<void> restoreEntry(String id) async {
    await _send('POST', _uri('/diary/restore', {'id': id}));
  }

  // ESPORTA TUTTE LE NOTE IN MARKDOWN
  Future<String> exportMarkdown() async {
    final response = await _send('GET', _uri('/diary/export/markdown'));
    return utf8.decode(response.bodyBytes);
  }
}
