import 'package:net_kit/net_kit.dart';

/// Implementation of the [INetKitLogger] interface. Note:
/// uncomment the print statements to see the logs in the console.
class NetworkLogger implements INetKitLogger {
  const NetworkLogger();

  @override
  void trace(String message) {
    // print(message);
  }

  @override
  void debug(String message) {
    // print(message);
  }

  @override
  void info(String message) {
    // print(message);
  }

  @override
  void warning(String message) {
    // print(message);
  }

  @override
  void error(String? message) {
    // print(message);
  }

  @override
  void fatal(String? message) {
    // print(message);
  }
}
