import 'package:dev_diary/main.dart';
import 'package:dev_diary/services/diary_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('app uses the bundled font and new colors', (tester) async {
    DiaryApiService.defaultClient = MockClient(
      (req) async => http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    addTearDown(() => DiaryApiService.defaultClient = null);

    await tester.pumpWidget(const DevDiaryApp());
    await tester.pump(const Duration(milliseconds: 100));

    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(theme.textTheme.bodyMedium!.fontFamily, 'BricolageGrotesque');
    expect(theme.scaffoldBackgroundColor, const Color(0xFFECEFF5));
    expect(tester.takeException(), isNull);
  });
}
