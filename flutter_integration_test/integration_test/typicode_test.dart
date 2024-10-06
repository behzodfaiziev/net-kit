import 'package:android_integration_test/main.dart' as app;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Android CRUD Integration Test', () {
    testWidgets('Create Comment Test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      final createCommentButton = find.byKey(const Key('createCommentButton'));
      await tester.tap(createCommentButton);
      await tester.pumpAndSettle();

      final nameField = find.byKey(const Key('nameField'));
      await tester.enterText(nameField, 'New Comment Name');
      await tester.pumpAndSettle();

      final emailField = find.byKey(const Key('emailField'));
      await tester.enterText(emailField, 'email@test.com');
      await tester.pumpAndSettle();

      final submitButton = find.byKey(const Key('submitButton'));
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('New Comment Name'), findsOneWidget);
    });
  });
}