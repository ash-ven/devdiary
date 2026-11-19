import 'package:dev_diary/main.dart';
import 'package:dev_diary/screens/dashboard_screen.dart';
import 'package:dev_diary/services/diary_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

const apiMessage = 'Database non disponibile';

void useFailingApi() {
  DiaryApiService.defaultClient = MockClient((req) async => http.Response(
        '{"error":true,"code":"DATABASE_UNAVAILABLE","message":"$apiMessage"}',
        503,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ));
  addTearDown(() => DiaryApiService.defaultClient = null);
}

void main() {
  testWidgets('the list shows the api message when loading fails', (tester) async {
    useFailingApi();
    await tester.pumpWidget(const DevDiaryApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining(apiMessage), findsOneWidget);
  });

  testWidgets('the dashboard shows the api message when loading fails', (tester) async {
    useFailingApi();
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining(apiMessage), findsOneWidget);
  });
}
