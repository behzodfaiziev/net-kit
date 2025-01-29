import 'dart:core';

import '../enum/http_status_codes.dart';
import '../manager/error/api_exception.dart';
import '../model/i_net_kit_model.dart';
import 'typedef/request_type_def.dart';

/// The Converters class contains methods to convert data
class Converter {
  /// The constructor for the Converters class
  const Converter();

  /// Converts the data to a list of models
  /// It takes in the following parameters:
  /// `data`: The data to convert
  /// `parseModel`: The model to parse the data to
  /// It returns a list of models
  /// If the data is a list, converts it to a list of models
  /// If the data is not within the above conditions, returns an empty list
  List<T> toListModel<T extends INetKitModel>({
    required dynamic data,
    required T parseModel,
  }) {
    try {
      /// If the data is a list, convert it to a list of models
      if (data is List<dynamic>) {
        return data

        /// Filter the data to only include maps
            .whereType<MapType>()

        /// Convert the data to a model
            .map((data) => parseModel.fromJson(data))

        /// Cast the data to the model type
            .cast<T>()

        /// Convert the converted models to a list
            .toList();
      }

      /// If the data is not a list, throw an exception
      throw ApiException(
        message: 'The data is not a list',
        statusCode: HttpStatuses.expectationFailed.code,
      );
    } on ApiException {
      rethrow;
    } on Exception catch (_) {
      /// If an error occurs, throw ApiException
      throw ApiException(
        message: 'Could not parse the list response',
        statusCode: HttpStatuses.expectationFailed.code,
      );
    }
  }

  /// Converts the data to a model
  /// It takes in the following parameters:
  /// `data`: The data to convert
  /// `parsingModel`: The model to parse the data to
  /// It returns a model
  R toModel<R extends INetKitModel>(MapType data, R parsingModel) {
    try {
      /// Convert the data to a model
      return parsingModel.fromJson(data) as R;
    } on Exception catch (_) {
      /// If an error occurs, throw ApiException
      throw ApiException(
        message: 'Could not parse the response: ${R.runtimeType}',
        statusCode: HttpStatuses.expectationFailed.code,
      );
    }
  }
}
