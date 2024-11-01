import 'i_net_kit_logger.dart';

/// Implementation of the default [INetKitLogger] interface
/// which does not log anything. In order to use this logger,
/// a custom instance of the [INetKitLogger] class must be created.
/// And injected into the NetKitManager class.
final class VoidLogger implements INetKitLogger {
  /// Default constructor
  const VoidLogger();

  @override
  void trace(String message) {}

  @override
  void debug(String message) {}

  @override
  void info(String message) {}

  @override
  void warning(String message) {}

  @override
  void error(String? message) {}

  @override
  void fatal(String? message) {}
}
