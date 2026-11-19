import 'package:dev_diary/services/request_log.dart';
import 'package:flutter_test/flutter_test.dart';

RequestRecord record(int n) => RequestRecord(
  method: 'GET',
  pathAndQuery: '/diary?n=$n',
  status: 200,
  durationMs: n,
  at: DateTime(2026, 11, 19),
);

void main() {
  test('keeps only the last 20 records', () {
    final log = RequestLog();
    var notified = 0;
    log.addListener(() => notified++);
    for (var i = 0; i < 25; i++) {
      log.add(record(i));
    }
    expect(log.records, hasLength(20));
    expect(log.records.first.durationMs, 24);
    expect(log.records.last.durationMs, 5);
    expect(notified, 25);
  });
}
