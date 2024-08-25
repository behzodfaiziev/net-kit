//ignore_for_file: avoid_print
import 'package:net_kit/net_kit.dart';

import 'models/todo_model.dart';

/// A very basic example of how to use the NetKit package.
void main() {
  /// Create a new instance of the NetKitManager class.
  /// The base URL is set to 'https://jsonplaceholder.typicode.com'.
  final INetKitManager netKitManager = NetKitManager(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    loggerEnabled: true,
  );

  TodoRemoteDataSource(netKitManager: netKitManager)
    ..getTodoList()
    ..getTodo(1)
    ..createTodo(TodoModel(id: 1, title: 'Test', userId: 1, completed: false))
    ..deleteTodoById(1);
}

class TodoRemoteDataSource {
  TodoRemoteDataSource({required INetKitManager netKitManager})
      : _netKitManager = netKitManager;

  final INetKitManager _netKitManager;

  Future<void> deleteTodoById(int id) async {
    try {
      await _netKitManager.requestVoid(
        path: '/todos/$id',
        method: RequestMethod.delete,
      );

      print('Todo deleted successfully');
    } on ApiException catch (e) {
      /// This will print the error message.
      print(e.message);
    }
  }

  Future<void> getTodo(int id) async {
    try {
      final todo = await _netKitManager.requestModel(
        path: '/todos/$id',
        method: RequestMethod.get,
        model: TodoModel(),
      );

      /// This will print the TodoModel object.
      print(todo);
    } on ApiException catch (e) {
      /// This will print the error message.
      print(e.message);
    }
  }

  Future<void> getTodoList() async {
    try {
      final todos = await _netKitManager.requestList(
        path: '/todos',
        method: RequestMethod.get,
        model: TodoModel(),
      );

      /// This will print the length of TodoModel objects.
      print('Todos length: ${todos.length}');
    } on ApiException catch (e) {
      /// This will print the error message.
      print(e.message);
    }
  }

  Future<void> createTodo(TodoModel todo) async {
    try {
      final createdTodo = await _netKitManager.requestModel(
        path: '/todos',
        method: RequestMethod.post,
        model: TodoModel(),
        body: todo,
      );

      /// This will print the created TodoModel object.
      print('Created Todo: $createdTodo');
    } on ApiException catch (e) {
      /// This will print the error message.
      print(e.message);
    }
  }
}
