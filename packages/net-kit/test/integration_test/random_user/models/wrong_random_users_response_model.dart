import 'package:net_kit/net_kit.dart';

import 'wrong_type_user_model.dart';

class WrongRandomUsersResponseModel extends INetKitModel {
  const WrongRandomUsersResponseModel({this.results});

  factory WrongRandomUsersResponseModel.fromJson(Map<String, dynamic> json) {
    return WrongRandomUsersResponseModel(
      results: (json['results'] as List<dynamic>?)
          ?.map((e) => WrongTypeUserModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<WrongTypeUserModel>? results;

  @override
  WrongRandomUsersResponseModel fromJson(Map<String, dynamic> json) =>
      WrongRandomUsersResponseModel.fromJson(json);

  @override
  Map<String, dynamic>? toJson() => {'results': results};
}
