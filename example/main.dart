import 'package:net_kit/net_kit.dart';
import 'package:net_kit/src/manager/logger/i_net_kit_logger.dart';
import 'package:net_kit/src/manager/logger/net_kit_logger.dart';

import 'models/todo_model.dart';

/// A very basic example of how to use the NetKit package.
void main() {
  /// Create a new instance of the NetKitManager class.
  /// The base URL is set to 'https://jsonplaceholder.typicode.com'.
  final netKitManager = NetKitManager(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    logLevel: LogLevel.all,
  );

  final logger = NetKitLogger();

  /// This is an example of how to use the TodoRemoteDataSource class.
  TodoRemoteDataSourceImpl(netKitManager: netKitManager, logger: logger)
    ..getTodoList()
    ..getTodo(1)
    ..createTodo(TodoModel(id: 1, title: 'Test', userId: 1, completed: false))
    ..deleteTodoById(1);
}

/// The abstract class for the TodoRemoteDataSource
/// It contains methods to interact with the todoModel
/// Note: The return type of the methods
/// is void only for demonstration purposes.
abstract class TodoRemoteDataSource {
  Future<void> deleteTodoById(int id);

  Future<void> getTodoList();

  Future<void> getTodo(int id);

  Future<void> createTodo(TodoModel todo);
}

/// Note: Make sure you inject the dependencies so that the class is testable
class TodoRemoteDataSourceImpl extends TodoRemoteDataSource {
  /// The constructor for the TodoRemoteDataSource class
  /// It takes in the following parameters:
  /// `netKitManager` and `logger` to be injected
  /// The `netKitManager` is used to make network requests
  /// The `logger` is used to logging.
  /// Note: It is not necessary to use the logger.
  /// It is used for demonstration purposes.
  TodoRemoteDataSourceImpl({
    required INetKitManager netKitManager,
    required INetKitLogger logger,
  })  : _netKitManager = netKitManager,
        _logger = logger;

  final INetKitManager _netKitManager;
  final INetKitLogger _logger;

  @override
  Future<void> deleteTodoById(int id) async {
    try {
      await _netKitManager.requestVoid(
        path: '/todos/$id',
        method: RequestMethod.delete,
      );

      /// Handle the success case.
      /// As an example, log the success message
      /// or return as a String message.
      _logger.debug('Todo deleted successfully');
    } on ApiException catch (e) {
      /// Handle the error from backend which is thrown as ApiException.
      /// As an example, error message is printed.
      _logger.error(e.message);
    }
  }

  @override
  Future<void> getTodo(int id) async {
    try {
      final todo = await _netKitManager.requestModel(
        path: '/todos/$id',
        method: RequestMethod.get,
        model: TodoModel(),
      );

      /// Handle the success case.
      /// As an example, log the success message
      /// or return the [`TodoModel`].
      _logger.debug(todo.toString());
    } on ApiException catch (e) {
      /// Handle the error from backend which is thrown as ApiException.
      /// As an example, error message is printed.
      _logger.error(e.message);
    }
  }

  @override
  Future<void> getTodoList() async {
    try {
      final todos = await _netKitManager.requestList(
        path: '/todos',
        method: RequestMethod.get,
        model: TodoModel(),
      );

      /// Handle the success case.
      /// As an example, log the success message
      /// or return the list as [`List<TodoModel>`].
      _logger.info('Todos length: ${todos.length}');
    } on ApiException catch (e) {
      /// Handle the error from backend which is thrown as ApiException.
      /// As an example, error message is printed.
      _logger.error(e.message);
    }
  }

  @override
  Future<void> createTodo(TodoModel todo) async {
    try {
      final createdTodo = await _netKitManager.requestModel(
        path: '/todos',
        method: RequestMethod.post,
        model: TodoModel(),
        body: todo,
      );

      /// Handle the success case.
      /// As an example, log the success message
      /// or return the created [`TodoModel`].
      _logger.debug('Created Todo: $createdTodo');
    } on ApiException catch (e) {
      /// Handle the error from backend which is thrown as ApiException.
      /// As an example, error message is printed.
      _logger.error(e.message);
    }
  }
}
