import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/diary_entry.dart';

class DiaryApiService {
  static const String baseUrl = 'http://localhost:5678/webhook';

  // GET STATUS
  Future<String> getStatus() async {
    final response = await http.get(
      Uri.parse('$baseUrl/status'),
    );

    if (response.statusCode == 200) {
      final dynamic data = jsonDecode(response.body);

      return data['Status']?.toString() ??
          data['status']?.toString() ??
          'OK';
    }

    throw Exception(
      'Errore API: ${response.statusCode}',
    );
  }

  // GET NOTE CON FILTRI OPZIONALI
  Future<List<DiaryEntry>> getEntries({
    String? type,
    bool? favorite,
    String? tag,
    String? search,
  }) async {
    final queryParameters = <String, String>{};

    if (type != null && type.isNotEmpty) {
      queryParameters['type'] = type;
    }

    if (favorite != null) {
      queryParameters['favorite'] = favorite.toString();
    }

    if (tag != null && tag.isNotEmpty) {
      queryParameters['tag'] = tag;
    }

    if (search != null && search.isNotEmpty) {
      queryParameters['search'] = search;
    }

    final uri = Uri.parse(
      '$baseUrl/diary',
    ).replace(
      queryParameters:
          queryParameters.isEmpty ? null : queryParameters,
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final dynamic data = jsonDecode(response.body);

      if (data is List) {
        return data
            .map(
              (item) => DiaryEntry.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      }

      if (data is Map<String, dynamic>) {
        return [
          DiaryEntry.fromJson(data),
        ];
      }

      throw Exception(
        'Formato della risposta non valido',
      );
    }

    throw Exception(
      'Errore caricamento note: ${response.statusCode}',
    );
  }

  // GET NOTA PER ID
  Future<DiaryEntry> getEntryById(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/diary/detail?id=$id'),
    );

    if (response.statusCode == 200) {
      final dynamic data = jsonDecode(response.body);

      if (data is Map<String, dynamic>) {
        return DiaryEntry.fromJson(data);
      }

      throw Exception(
        'Formato della nota non valido',
      );
    }

    throw Exception(
      'Errore caricamento nota: ${response.statusCode}',
    );
  }

  // CREA NOTA
  Future<void> createEntry(DiaryEntry entry) async {
    final response = await http.post(
      Uri.parse('$baseUrl/diary'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(entry.toJson()),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(
        'Errore creazione nota: ${response.statusCode}',
      );
    }
  }

  // MODIFICA NOTA
  Future<void> updateEntry(DiaryEntry entry) async {
    final response = await http.put(
      Uri.parse('$baseUrl/diary?id=${entry.id}'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(entry.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Errore aggiornamento nota: ${response.statusCode}',
      );
    }
  }

  // ELIMINA NOTA
  Future<void> deleteEntry(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/diary?id=$id'),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Errore eliminazione nota: ${response.statusCode}',
      );
    }
  }
}