/// Errore restituito dall'API (o dalla rete), con un messaggio pronto da mostrare.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message);

  /// Codice HTTP; 0 se la risposta non è arrivata (timeout, rete).
  final int statusCode;

  /// Codice stabile dell'API (es. `SAMPLE_READ_ONLY`) oppure `HTTP_<stato>`, `TIMEOUT`, `NETWORK`.
  final String code;

  final String message;

  @override
  String toString() => message;
}
