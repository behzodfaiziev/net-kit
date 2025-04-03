import 'package:net_kit/net_kit.dart';

class UserNameModel extends INetKitModel {
  const UserNameModel({
    this.title,
    this.first,
    this.last,
  });

  factory UserNameModel.fromJson(Map<String, dynamic> json) {
    return UserNameModel(
      title: json['title'] as String?,
      first: json['first'] as String?,
      last: json['last'] as String?,
    );
  }

  final String? title;
  final String? first;
  final String? last;

  @override
  UserNameModel fromJson(Map<String, dynamic> json) => UserNameModel.fromJson(json);

  @override
  Map<String, dynamic>? toJson() => {
        'title': title,
        'first': first,
        'last': last,
      };
}
