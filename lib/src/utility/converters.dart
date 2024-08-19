import '../model/i_net_kit_model.dart';
import 'typedef/request_type_def.dart';

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

  static List<T> toListModel<T extends INetKitModel<T>>(
    dynamic data,
    T parseModel,
  ) {
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
  }

  static T toModel<T extends INetKitModel<T>>(MapType data, T parseModel) {
    return parseModel.fromJson(data);
  }
}
