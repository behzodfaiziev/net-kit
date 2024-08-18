abstract class INetKitModel<T> {
  /// Constructor for the model
  /// [T] is the model type
  const INetKitModel();

  /// Convert the model to json
  Map<String, dynamic>? toJson();

  /// Convert the json to model
  T fromJson(Map<String, dynamic> json);
}
