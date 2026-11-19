import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/diary_entry.dart';
import 'api_config.dart';
import 'api_exception.dart';

class DiaryApiService {
  DiaryApiService({
    http.Client? client,
    String? baseUrl,
    String? visitorId,
    this.timeout = const Duration(seconds: 30),
  })  : _client = client ?? defaultClient ?? http.Client(),
        baseUrl = normalizeBaseUrl(baseUrl ?? apiBaseUrl),
        visitorId = visitorId ?? defaultVisitorId;

  /// Client condiviso: i test lo sostituiscono con un MockClient.
  static http.Client? defaultClient;

  /// Identificativo anonimo del visitatore della demo, impostato all'avvio.
  static String? defaultVisitorId;

  final http.Client _client;
  final String baseUrl;
  final String? visitorId;
  final Duration timeout;

  Map<String, String> _headers({bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
        'X-Demo-Visitor': ?visitorId,
      };

  /// Esegue una richiesta e trasforma timeout, errori di rete e risposte d'errore in ApiException.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException(0, 'TIMEOUT', 'Il server non risponde: potrebbe essere in avvio, riprova tra un minuto.');
    } on http.ClientException {
      throw const ApiException(0, 'NETWORK', 'Impossibile raggiungere il server.');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return response;
    throw _errorFrom(response);
  }

  ApiException _errorFrom(http.Response response) {
    final status = response.statusCode;
    try {
      final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map<String, dynamic> && data['message'] is String) {
        return ApiException(status, data['code']?.toString() ?? 'HTTP_$status', data['message'] as String);
      }
    } on FormatException {
      // corpo non JSON (es. pagina HTML del proxy di Render)
    }
    return ApiException(status, 'HTTP_$status', 'Il server ha risposto con un errore ($status). Riprova tra poco.');
  }

  dynamic _json(http.Response response) => jsonDecode(utf8.decode(response.bodyBytes));

  // GET STATUS
  Future<String> getStatus() async {
    final response = await _send(() => _client.get(Uri.parse('$baseUrl/status'), headers: _headers()));
    final dynamic data = _json(response);
    return data['status']?.toString() ?? data['Status']?.toString() ?? 'OK';
  }

  // GET NOTE CON FILTRI OPZIONALI
  Future<List<DiaryEntry>> getEntries({
    String? type,
    bool? favorite,
    String? tag,
    String? search,
  }) async {
    final queryParameters = <String, String>{
      if (type != null && type.isNotEmpty) 'type': type,
      if (favorite != null) 'favorite': favorite.toString(),
      if (tag != null && tag.isNotEmpty) 'tag': tag,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final uri = Uri.parse('$baseUrl/diary').replace(queryParameters: queryParameters.isEmpty ? null : queryParameters);
    final response = await _send(() => _client.get(uri, headers: _headers()));
    final dynamic data = _json(response);
    if (data is List) {
      return data.map((item) => DiaryEntry.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    }
    if (data is Map<String, dynamic>) return [DiaryEntry.fromJson(data)];
    throw const ApiException(200, 'FORMAT', 'Formato della risposta non valido');
  }

  // GET NOTA PER ID
  Future<DiaryEntry> getEntryById(String id) async {
    final uri = Uri.parse('$baseUrl/diary/detail').replace(queryParameters: {'id': id});
    final response = await _send(() => _client.get(uri, headers: _headers()));
    final dynamic data = _json(response);
    if (data is Map<String, dynamic>) return DiaryEntry.fromJson(data);
    throw const ApiException(200, 'FORMAT', 'Formato della nota non valido');
  }

  // CREA NOTA
  Future<void> createEntry(DiaryEntry entry) async {
    await _send(() => _client.post(Uri.parse('$baseUrl/diary'), headers: _headers(json: true), body: jsonEncode(entry.toJson())));
  }

  // MODIFICA NOTA
  Future<void> updateEntry(DiaryEntry entry) async {
    final uri = Uri.parse('$baseUrl/diary').replace(queryParameters: {'id': entry.id});
    await _send(() => _client.put(uri, headers: _headers(json: true), body: jsonEncode(entry.toJson())));
  }

  // ELIMINA NOTA (la sposta nel cestino)
  Future<void> deleteEntry(String id) async {
    final uri = Uri.parse('$baseUrl/diary').replace(queryParameters: {'id': id});
    await _send(() => _client.delete(uri, headers: _headers()));
  }
}
