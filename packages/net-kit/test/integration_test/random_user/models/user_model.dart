import 'package:net_kit/net_kit.dart';

import 'user_name_model.dart';

class UserModel extends INetKitModel {
  const UserModel({
    this.gender,
    this.name,
    this.email,
    this.phone,
    this.cell,
    this.nat,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      gender: json['gender'] as String?,
      name: json['name'] == null
          ? null
          : UserNameModel.fromJson(json['name'] as Map<String, dynamic>),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      cell: json['cell'] as String?,
      nat: json['nat'] as String?,
    );
  }

  final String? gender;
  final UserNameModel? name;
  final String? email;
  final String? phone;
  final String? cell;
  final String? nat;

  @override
  UserModel fromJson(Map<String, dynamic> json) => UserModel.fromJson(json);

  @override
  Map<String, dynamic>? toJson() => {
        'gender': gender,
        'name': name,
        'email': email,
        'phone': phone,
        'cell': cell,
        'nat': nat,
      };
}
