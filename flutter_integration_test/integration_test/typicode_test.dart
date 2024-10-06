import 'package:android_integration_test/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Android CRUD Integration Test', () {
    testWidgets('Create Comment Test', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      // Add a delay to ensure the initial comments are fetched
      await Future<void>.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Fetch initial list of comments and ensure it is non-empty
      final initialComments = find.byType(ListTile);
      expect(
        initialComments,
        findsWidgets,
        reason: 'Initial comments list is empty',
      );

      // Create a new comment
      final createCommentButton = find.byKey(const Key('createCommentButton'));
      expect(
        createCommentButton,
        findsOneWidget,
        reason: 'Create Comment Button not found',
      );
      await tester.tap(createCommentButton);
      await tester.pumpAndSettle();

      final nameField = find.byKey(const Key('nameField'));
      expect(nameField, findsOneWidget, reason: 'Name Field not found');
      await tester.enterText(nameField, 'New Comment Name');
      await tester.pumpAndSettle();

      final emailField = find.byKey(const Key('emailField'));
      expect(emailField, findsOneWidget, reason: 'Email Field not found');
      await tester.enterText(emailField, 'email@test.com');
      await tester.pumpAndSettle();

      final submitButton = find.byKey(const Key('submitButton'));
      expect(submitButton, findsOneWidget, reason: 'Submit Button not found');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Debugging: Print the widget tree
      debugPrint(tester.element(find.byType(app.MyApp)).toStringDeep());

      // Wait for a short duration to ensure the comment is created
      await Future<void>.delayed(const Duration(seconds: 2));

      // Verify that the new comment is inserted at the beginning of the list
      final newComment = find.text('New Comment Name');
      expect(newComment, findsOneWidget, reason: 'New Comment Name not found');

      // Verify that the new comment is the first item in the list
      final firstComment = tester.widget<ListTile>(find.byType(ListTile).first);
      expect(
        firstComment.title,
        isA<Text>().having((t) => t.data, 'text', 'New Comment Name'),
      );
      expect(
        firstComment.subtitle,
        isA<Text>().having((t) => t.data, 'text', 'email@test.com'),
      );
    });
  });
}
