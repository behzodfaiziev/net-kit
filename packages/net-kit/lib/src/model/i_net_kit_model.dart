/// Interface for the model
/// It is used to convert the model to json and vice versa
/// [INetKitModel] is the model type
///
/// Convert the json to model
/// - `INetKitModel fromJson(Map<String, dynamic> json);`
///
/// Convert the model to json
/// - `Map<String, dynamic>? toJson();`
///
/// It is required to implement the [fromJson] and [toJson] methods
/// to convert the model to json and vice versa
///
/// It makes sure that only models which are extending this class
/// can be used by the network manager
abstract class INetKitModel {
  /// Constructor for the model
  const INetKitModel();

  /// Convert the model to json
  Map<String, dynamic>? toJson();

  /// [INetKitModel] is the model type
  /// Convert the json to model
  INetKitModel fromJson(Map<String, dynamic> json);
}
