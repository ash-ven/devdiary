import 'package:flutter/foundation.dart';

/// Una richiesta HTTP fatta all'API (status 0 = errore di rete o timeout).
class RequestRecord {
  const RequestRecord({
    required this.method,
    required this.pathAndQuery,
    required this.status,
    required this.durationMs,
    required this.at,
  });

  final String method;
  final String pathAndQuery;
  final int status;
  final int durationMs;
  final DateTime at;
}

/// Ultime richieste fatte all'API, la più recente per prima.
class RequestLog extends ChangeNotifier {
  static const maxRecords = 20;

  /// Istanza condivisa dall'app.
  static final RequestLog shared = RequestLog();

  final List<RequestRecord> _records = [];

  List<RequestRecord> get records => List.unmodifiable(_records);

  void add(RequestRecord record) {
    _records.insert(0, record);
    if (_records.length > maxRecords) {
      _records.removeRange(maxRecords, _records.length);
    }
    notifyListeners();
  }
}
