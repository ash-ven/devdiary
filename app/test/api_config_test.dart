import 'package:dev_diary/services/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes the base url', () {
    expect(normalizeBaseUrl('https://a.example/webhook/'), 'https://a.example/webhook');
    expect(normalizeBaseUrl('https://a.example/webhook///'), 'https://a.example/webhook');
    expect(normalizeBaseUrl('https://a.example/webhook'), 'https://a.example/webhook');
    expect(normalizeBaseUrl('  https://a.example/webhook/  '), 'https://a.example/webhook');
  });

  test('defaults to the local api', () {
    expect(apiBaseUrl, 'http://localhost:5678/webhook');
  });
}
