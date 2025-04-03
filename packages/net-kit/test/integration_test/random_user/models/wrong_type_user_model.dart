import 'package:net_kit/net_kit.dart';

import 'user_name_model.dart';

class WrongTypeUserModel extends INetKitModel {
  const WrongTypeUserModel({
    this.gender,
    this.name,
    this.email,
    this.phone,
    this.cell,
    this.nat,
  });

  factory WrongTypeUserModel.fromJson(Map<String, dynamic> json) {
    return WrongTypeUserModel(
      gender: json['gender'] as double?,
      name: json['name'] == null
          ? null
          : UserNameModel.fromJson(json['name'] as Map<String, dynamic>),
      email: json['email'] as int?,
      phone: json['phone'] as List<String>?,
      cell: json['cell'] as bool?,
      nat: json['nat'] as String?,
    );
  }

  final double? gender;
  final UserNameModel? name;
  final int? email;
  final List<String>? phone;
  final bool? cell;
  final String? nat;

  @override
  WrongTypeUserModel fromJson(Map<String, dynamic> json) => WrongTypeUserModel.fromJson(json);

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
