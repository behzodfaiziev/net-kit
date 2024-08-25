import 'dart:core';

import '../enum/http_status_codes.dart';
import '../manager/error/api_exception.dart';
import '../manager/logger/i_net_kit_logger.dart';
import '../model/i_net_kit_model.dart';
import 'typedef/request_type_def.dart';

/// The Converters class contains methods to convert data
class Converter {
  /// The constructor for the Converters class
  Converter({required INetKitLogger logger}) : _logger = logger;

  final INetKitLogger _logger;

  /// Converts the data to a request body data.
  dynamic toRequestBody({
    required dynamic data,
    bool loggerEnabled = false,
  }) async {
    /// If the data is null, return null
    if (data == null) return null;

    /// The stopwatch to measure the time taken to convert the data
    Stopwatch? stopwatch;

    /// Start the stopwatch if the logger is enabled
    if (loggerEnabled) stopwatch = Stopwatch()..start();

    /// If the data is a model, convert it to JSON
    if (data is INetKitModel) {
      final jsonData = data.toJson();

      /// Log the event
      if (loggerEnabled) _logEvent(type: 'toRequestBody', stopwatch: stopwatch);
      return jsonData;
    }

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
  List<T> toListModel<T extends INetKitModel<T>>({
    required dynamic data,
    required T parseModel,
    bool loggerEnabled = false,
  }) {
    try {
      /// If the data is a list, convert it to a list of models
      if (data is List<dynamic>) {
        /// The stopwatch to measure the time taken to convert the data
        Stopwatch? stopwatch;

        /// Start the stopwatch if the logger is enabled
        if (loggerEnabled) stopwatch = Stopwatch()..start();

        final parsedList = data

            /// Filter the data to only include maps
            .whereType<MapType>()

            /// Convert the data to a model
            .map((data) => parseModel.fromJson(data))

            /// Cast the data to the model type
            .cast<T>()

            /// Convert the converted models to a list
            .toList();

        /// Log the event if the logger is enabled
        if (loggerEnabled) {
          _logListParsingEvent(
            stopwatch: stopwatch,
            length: parsedList.length,
          );
        }
        return parsedList;
      }

      /// If the data is not a list, throw an exception
      throw ApiException(
        message: 'The data is not a list',
        statusCode: HttpStatuses.expectationFailed.code,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
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

  void _logEvent({required String type, Stopwatch? stopwatch}) {
    stopwatch?.stop();
    _logger.info(
      'Converter: $type: ${stopwatch?.elapsedMilliseconds}ms',
    );
  }

  Future<void> _logListParsingEvent({
    required int length,
    Stopwatch? stopwatch,
  }) async {
    stopwatch?.stop();
    _logger.info(
      'Converter.toListModel,'
      ' $length items: ${stopwatch?.elapsedMilliseconds}ms',
    );
  }
}
