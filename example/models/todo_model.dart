import 'package:net_kit/net_kit.dart';

class TodoModel extends INetKitModel<TodoModel> {
  TodoModel({
    this.userId,
    this.id,
    this.title,
    this.completed,
  });

  final int? userId;
  final int? id;
  final String? title;
  final bool? completed;

  @override
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'id': id,
      'title': title,
      'completed': completed,
    };
  }

  @override
  TodoModel fromJson(Map<String, dynamic> json) {
    return TodoModel(
      userId: json['userId'] as int?,
      id: json['id'] as int?,
      title: json['title'] as String?,
      completed: json['completed'] as bool?,
    );
  }

  @override
  String toString() {
    return 'TodoModel{'
        'userId: $userId, '
        'id: $id, '
        'title: $title, '
        'completed: $completed'
        '}';
  }
}
