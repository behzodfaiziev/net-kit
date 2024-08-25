import 'package:net_kit/net_kit.dart';
import 'package:test/test.dart';

import 'models/typicode_comment_model.dart';

void main() {
  late INetKitManager netKitManager;

  setUp(() {
    netKitManager =
        NetKitManager(baseUrl: 'https://jsonplaceholder.typicode.com');
  });

  group('Comment Test Correct Method: requestList', () {
    test('Get List of Comments', () async {
      try {
        final comments = await netKitManager.requestList<TypicodeCommentModel>(
          path: '/comments',
          model: const TypicodeCommentModel(),
          method: RequestMethod.get,
        );

        expect(comments, isA<List<TypicodeCommentModel>>());
        expect(comments.isNotEmpty, true);
        expect(comments.first, isA<TypicodeCommentModel>());
      } on ApiException catch (e) {
        fail('Request failed with error: ${e.message}');
      }
    });

    test('Get Comment by ID', () async {
      try {
        final comment = await netKitManager.requestModel<TypicodeCommentModel>(
          path: '/comments/4',
          model: const TypicodeCommentModel(),
          method: RequestMethod.get,
        );
        expect(comment, isA<TypicodeCommentModel>());
        expect(comment.id, 4);
      } on ApiException catch (e) {
        fail('Request failed with error: ${e.message}');
      }
    });

    test('Create a Comment', () async {
      try {
        const comment =
            TypicodeCommentModel(postId: 1, id: 1, name: 'Test', email: 'test');

        final createdComment =
            await netKitManager.requestModel<TypicodeCommentModel>(
          path: '/comments',
          method: RequestMethod.post,
          model: const TypicodeCommentModel(),
          body: comment.toJson(),
        );

        expect(createdComment, isA<TypicodeCommentModel>());
      } on ApiException catch (e) {
        fail('Request failed with error: ${e.message}');
      }
    });

    test('Delete a Comment', () async {
      try {
        await netKitManager.requestVoid(
          path: '/comments/1',
          method: RequestMethod.delete,
        );

        expect(true, true);
      } on ApiException catch (e) {
        fail('Request failed with error: ${e.message}');
      }
    });
  });
}
