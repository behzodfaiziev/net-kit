import 'package:logger/logger.dart' show Logger, PrettyPrinter;
import 'package:net_kit/net_kit.dart';

/// Implementation of the [INetKitLogger] interface
class NetworkLogger implements INetKitLogger {
  final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
    ),
  );

  @override
  void trace(String message) {
    _logger.t(message);
  }

  @override
  void debug(String message) {
    _logger.d(message);
  }

  @override
  void info(String message) {
    _logger.i(message);
  }

  @override
  void warning(String message) {
    _logger.w(message);
  }

  @override
  void error(String? message) {
    _logger.e(message);
  }

  @override
  void fatal(String? message) {
    _logger.e(message);
  }
}
