import '../enum/http_status_codes.dart';
import '../error/api_exception.dart';
import '../model/i_net_kit_model.dart';
import 'typedef/request_type_def.dart';

/// The Converters class contains methods to convert data
class Converters {
  /// Converts the data to a request body data.
  static dynamic toRequestBody(dynamic data) {
    /// If the data is null, return null
    if (data == null) return null;

    /// If the data is a model, convert it to JSON
    if (data is INetKitModel) return data.toJson();

    /// if the data is not within the above conditions, return the data as it is
    return data;
  }

  /// Converts the data to a list of models
  /// It takes in the following parameters:
  /// `data`: The data to convert
  /// `parseModel`: The model to parse the data to
  /// It returns a list of models
  /// If the data is a list, converts it to a list of models
  /// If the data is not within the above conditions, returns an empty list
  static List<T> toListModel<T extends INetKitModel<T>>(
    dynamic data,
    T parseModel,
  ) {
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

      /// If the data is not within the above conditions, return an empty list
      return <T>[];
    } catch (e) {
      /// If an error occurs, throw ApiException
      throw ApiException(
        message: 'Could not parse the response: ${T.runtimeType}',
        statusCode: HttpStatuses.expectationFailed.code,
      );
    }
  }

  /// Converts the data to a model
  /// It takes in the following parameters:
  /// `data`: The data to convert
  /// `parseModel`: The model to parse the data to
  /// It returns a model
  static T toModel<T extends INetKitModel<T>>(MapType data, T parseModel) {
    try {
      /// Convert the data to a model
      return parseModel.fromJson(data);
    } catch (e) {
      /// If an error occurs, throw ApiException
      throw ApiException(
        message: 'Could not parse the response: ${T.runtimeType}',
        statusCode: HttpStatuses.expectationFailed.code,
      );
    }
  }
}
