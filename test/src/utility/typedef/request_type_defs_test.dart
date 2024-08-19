import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:net_kit/src/model/error/error_model.dart';
import 'package:net_kit/src/utility/typedef/request_type_def.dart';

class MockErrorModel extends ErrorModel {
  MockErrorModel({required super.statusCode, required super.description});

  @override
  String get description => 'Mock error';
}

class MockResponseModel {
  MockResponseModel(this.data);

  final String data;
}

RequestModel<MockResponseModel> requestModel({bool shouldFail = false}) async {
  if (shouldFail) {
    return left(MockErrorModel(statusCode: 500, description: 'Mock error'));
  }
  return right(MockResponseModel('Success'));
}

RequestList<MockResponseModel> requestList({bool shouldFail = false}) async {
  if (shouldFail) {
    return left(MockErrorModel(statusCode: 500, description: 'Mock error'));
  }
  return right([MockResponseModel('Item1'), MockResponseModel('Item2')]);
}

RequestVoid requestVoid({bool shouldFail = false}) async {
  if (shouldFail) {
    return left(MockErrorModel(statusCode: 500, description: 'Mock error'));
  }
  return right(null);
}

void main() {
  group('RequestTypeDef', () {
    test('RequestModel returns Either<ErrorModel, R> on success', () async {
      final result = await requestModel();
      expect(result.isRight(), true);
      result.fold(
        (error) => fail('Expected a right value'),
        (response) => expect(response.data, 'Success'),
      );
    });

    test('RequestModel returns Either<ErrorModel, R> on error', () async {
      final result = await requestModel(shouldFail: true);
      expect(result.isLeft(), true);
      result.fold(
        (error) => expect(error.description, 'Mock error'),
        (response) => fail('Expected a left value'),
      );
    });

    test('RequestList returns Either<ErrorModel, List<R>> on success',
        () async {
      final result = await requestList();
      expect(result.isRight(), true);
      result.fold(
        (error) => fail('Expected a right value'),
        (response) {
          expect(response.length, 2);
          expect(response[0].data, 'Item1');
          expect(response[1].data, 'Item2');
        },
      );
    });

    test('RequestList returns Either<ErrorModel, List<R>> on error', () async {
      final result = await requestList(shouldFail: true);
      expect(result.isLeft(), true);
      result.fold(
        (error) => expect(error.description, 'Mock error'),
        (response) => fail('Expected a left value'),
      );
    });

    test('RequestVoid returns Either<ErrorModel, void> on success', () async {
      final result = await requestVoid();
      expect(result.isRight(), true);
      result.fold(
        (error) => fail('Expected a right value'),
        (_) => expect(null, null),
      );
    });

    test('RequestVoid returns Either<ErrorModel, void> on error', () async {
      final result = await requestVoid(shouldFail: true);
      expect(result.isLeft(), true);
      result.fold(
        (error) => expect(error.description, 'Mock error'),
        (_) => fail('Expected a left value'),
      );
    });
  });
}
