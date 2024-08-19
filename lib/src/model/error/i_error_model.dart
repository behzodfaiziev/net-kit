import '../i_net_kit_model.dart';

abstract class IErrorModel<T extends INetKitModel<T>?> {
  const IErrorModel({this.statusCode, this.description, this.error});

  final T? error;

  final int? statusCode;

  final String? description;
}
