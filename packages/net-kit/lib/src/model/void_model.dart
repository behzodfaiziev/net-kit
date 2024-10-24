import '../../net_kit.dart';

/// A model that does not have any data
/// This is used when the response is empty
/// or when the response is not needed
class VoidModel implements INetKitModel {
  @override
  Map<String, dynamic> toJson() => {};

  @override
  INetKitModel fromJson(Map<String, dynamic> json) {
    return VoidModel();
  }
}
