import 'package:net_kit/net_kit.dart';

import 'user_model.dart';

class RandomUsersResponseModel extends INetKitModel {
  const RandomUsersResponseModel({this.results});

  factory RandomUsersResponseModel.fromJson(Map<String, dynamic> json) {
    return RandomUsersResponseModel(
      results: (json['results'] as List<dynamic>?)
          ?.map((e) => UserModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<UserModel>? results;

  @override
  RandomUsersResponseModel fromJson(Map<String, dynamic> json) =>
      RandomUsersResponseModel.fromJson(json);

  @override
  Map<String, dynamic>? toJson() => {'results': results};
}
