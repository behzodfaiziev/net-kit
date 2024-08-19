abstract class INetKitModel<T> {
  /// Constructor for the model
  const INetKitModel();

  /// Convert the model to json
  Map<String, dynamic>? toJson();

  /// [T] is the model type
  /// Convert the json to model
  T fromJson(Map<String, dynamic> json);
}
