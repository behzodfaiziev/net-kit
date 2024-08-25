import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/enum/log_level.dart';
import 'package:net_kit/src/manager/logger/i_net_kit_logger.dart';
import 'package:net_kit/src/manager/logger/net_kit_logger.dart';

import 'models/todo_model.dart';

/// A very basic example of how to use the NetKit package.
void main() {
  /// Create a new instance of the NetKitManager class.
  /// The base URL is set to 'https://jsonplaceholder.typicode.com'.
  final INetKitManager netKitManager = NetKitManager(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    logLevel: LogLevel.all,
  );

  TodoRemoteDataSource(netKitManager: netKitManager, logger: NetKitLogger())
    ..getTodoList()
    ..getTodo(1)
    ..createTodo(TodoModel(id: 1, title: 'Test', userId: 1, completed: false))
    ..deleteTodoById(1);
}

class TodoRemoteDataSource {
  TodoRemoteDataSource({
    required INetKitManager netKitManager,
    required INetKitLogger logger,
  })  : _netKitManager = netKitManager,
        _logger = logger;

  final INetKitManager _netKitManager;
  final INetKitLogger _logger;

  Future<void> deleteTodoById(int id) async {
    try {
      await _netKitManager.requestVoid(
        path: '/todos/$id',
        method: RequestMethod.delete,
      );

      _logger.debug('Todo deleted successfully');
    } on ApiException catch (e) {
      /// This will print the error message.
      _logger.error(e.message);
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
      _logger.debug(todo.toString());
    } on ApiException catch (e) {
      /// This will print the error message.
      _logger.error(e.message);
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
      _logger.info('Todos length: ${todos.length}');
    } on ApiException catch (e) {
      /// This will print the error message.
      _logger.error(e.message);
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
      _logger.debug('Created Todo: $createdTodo');
    } on ApiException catch (e) {
      /// This will print the error message.
      _logger.error(e.message);
    }
  }
}
