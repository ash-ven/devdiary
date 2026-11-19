import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// UUID versione 4, casuale: identifica in modo anonimo il browser nella demo.
String generateVisitorId([Random? random]) {
  final rnd = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // versione 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Conserva l'identificativo nel browser (localStorage). Se lo storage non è disponibile,
/// usa un valore in memoria che resta uguale per tutta la sessione.
class VisitorStore {
  VisitorStore({Future<SharedPreferences> Function()? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance;

  static const key = 'devdiary.visitorId';
  static String? _memory;

  final Future<SharedPreferences> Function() _prefs;

  Future<String> load() async {
    try {
      final prefs = await _prefs();
      final stored = prefs.getString(key);
      if (stored != null && _uuidV4.hasMatch(stored)) return stored;
      final created = generateVisitorId();
      await prefs.setString(key, created);
      return created;
    } catch (_) {
      return _memory ??= generateVisitorId();
    }
  }
}
