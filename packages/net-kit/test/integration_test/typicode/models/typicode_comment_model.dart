import 'package:net_kit/net_kit.dart';

class TypicodeCommentModel extends INetKitModel {
  const TypicodeCommentModel({
    this.postId,
    this.id,
    this.name,
    this.email,
    this.body,
  });

  final int? postId;
  final int? id;
  final String? name;
  final String? email;
  final String? body;

  @override
  TypicodeCommentModel fromJson(Map<String, dynamic> json) => TypicodeCommentModel(
        postId: json['postId'] as int?,
        id: json['id'] as int?,
        name: json['name'] as String?,
        email: json['email'] as String?,
        body: json['body'] as String?,
      );

  @override
  Map<String, dynamic>? toJson() =>
      {'postId': postId, 'id': id, 'name': name, 'email': email, 'body': body};
}
