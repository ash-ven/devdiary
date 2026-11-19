/// Indirizzo dell'API n8n, fissato al momento della build:
/// `flutter build web --dart-define=API_BASE_URL=https://.../webhook`.
String normalizeBaseUrl(String raw) {
  var url = raw.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}

final String apiBaseUrl = normalizeBaseUrl(
  const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5678/webhook',
  ),
);
