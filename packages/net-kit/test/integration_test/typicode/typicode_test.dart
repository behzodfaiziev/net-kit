import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/enum/http_status_codes.dart';
import 'package:test/test.dart';

import 'models/typicode_comment_model.dart';

void main() {
  late INetKitManager netKitManager;

  setUp(() {
    netKitManager = NetKitManager(baseUrl: 'https://jsonplaceholder.typicode.com');
  });

  group('Comment Test Correct Methods', () {
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
        const comment = TypicodeCommentModel(
          postId: 1,
          id: 1,
          name: 'Name Test',
          email: 'Email test',
        );

        final createdComment = await netKitManager.requestModel<TypicodeCommentModel>(
          path: '/comments',
          method: RequestMethod.post,
          model: const TypicodeCommentModel(),
          body: comment.toJson(),
        );

        expect(createdComment, isA<TypicodeCommentModel>());
        expect(createdComment.id, 501);
        expect(createdComment.name, 'Name Test');
        expect(createdComment.email, 'Email test');
        expect(createdComment.postId, 1);
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

    test('Update a Comment', () async {
      try {
        const comment = TypicodeCommentModel(
          postId: 1,
          id: 1,
          name: 'Test',
          email: 'test',
        );

        final updatedComment = await netKitManager.requestModel<TypicodeCommentModel>(
          path: '/comments/1',
          method: RequestMethod.put,
          model: const TypicodeCommentModel(),
          body: comment.toJson(),
        );

        expect(updatedComment, isA<TypicodeCommentModel>());
      } on ApiException catch (e) {
        fail('Request failed with error: ${e.message}');
      }
    });
  });

  group('Comment Test Incorrect Methods', () {
    test('Get List of Comments', () async {
      try {
        final comments = await netKitManager.requestModel<TypicodeCommentModel>(
          path: '/comments',
          model: const TypicodeCommentModel(),
          method: RequestMethod.get,
        );

        fail('Request should have failed: $comments');
      } on ApiException catch (error) {
        expect(error.message, isA<String>());
        expect(error.statusCode, isA<int>());
        expect(error.statusCode, HttpStatuses.expectationFailed.code);
        expect(error.message, 'Could not parse the response: Not a Map type');
      }
    });

    test('Get Comment by ID', () async {
      try {
        final comment = await netKitManager.requestList<TypicodeCommentModel>(
          path: '/comments/4',
          model: const TypicodeCommentModel(),
          method: RequestMethod.get,
        );
        fail('Request should have failed: $comment');
      } on ApiException catch (e) {
        expect(e.message, 'The data is not a list');
        expect(e.statusCode, HttpStatuses.expectationFailed.code);
      }
    });

    test('Create a Comment', () async {
      try {
        const comment = TypicodeCommentModel(postId: 1, id: 1, name: 'Test', email: 'test');

        final createdComment = await netKitManager.requestList<TypicodeCommentModel>(
          path: '/comments',
          method: RequestMethod.post,
          model: const TypicodeCommentModel(),
          body: comment.toJson(),
        );

        fail('Request should have failed: $createdComment');
      } on ApiException catch (e) {
        expect(e.message, 'The data is not a list');
        expect(e.statusCode, HttpStatuses.expectationFailed.code);
      }
    });

    test('Delete a Comment', () async {
      try {
        final result = await netKitManager.requestList<TypicodeCommentModel>(
          path: '/comments/1',
          method: RequestMethod.delete,
          model: const TypicodeCommentModel(),
        );

        fail('Request should have failed: $result');
      } on ApiException catch (e) {
        expect(e.message, 'The data is not a list');
        expect(e.statusCode, HttpStatuses.expectationFailed.code);
      }
    });

    test('Update a Comment', () async {
      try {
        const comment = TypicodeCommentModel(
          postId: 1,
          id: 1,
          name: 'Test',
          email: 'test',
        );

        final updatedComment = await netKitManager.requestList<TypicodeCommentModel>(
          path: '/comments/1',
          method: RequestMethod.put,
          model: const TypicodeCommentModel(),
          body: comment.toJson(),
        );

        fail('Request should have failed: $updatedComment');
      } on ApiException catch (e) {
        expect(e.message, 'The data is not a list');
        expect(e.statusCode, HttpStatuses.expectationFailed.code);
      }
    });
  });
}
