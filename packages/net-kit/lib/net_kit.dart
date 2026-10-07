/// net_kit public API.
///
/// Everything exported here is owned by net_kit; no transport library type
/// appears. The Dio-backed transport lives in
/// `package:net_kit/net_kit_dio.dart`.
library;

/// Auth, timeouts, cancellation, progress, interception
export 'src/core/auth_policy.dart';
export 'src/core/net_kit_cancellation_token.dart' show NetKitCancellationToken;
export 'src/core/net_kit_interceptor.dart';
export 'src/core/net_kit_progress_callback.dart';
export 'src/core/net_kit_request_options.dart';
export 'src/core/net_kit_timeout.dart';

/// Enums
export 'src/enum/refresh_token_content_type.dart';
export 'src/enum/request_method.dart';

/// Exceptions
export 'src/manager/error/api_exception.dart';
export 'src/manager/error/api_failure_type.dart';

/// Manager
export 'src/manager/i_net_kit_manager.dart';
export 'src/manager/interceptors/redacting_log_interceptor.dart';
export 'src/manager/net_kit_manager.dart';
export 'src/manager/params/net_kit_error_params.dart';
export 'src/manager/params/net_kit_params.dart';

/// Models
export 'src/model/api_meta_response.dart';
export 'src/model/auth_token_model.dart';
export 'src/model/i_net_kit_model.dart';
export 'src/model/void_model.dart';

/// Transport contract and raw HTTP types
export 'src/raw/net_kit_transport.dart';
export 'src/raw/raw_http_body.dart';
export 'src/raw/raw_http_cancellation_token.dart' show RawHttpCancellationToken;
export 'src/raw/raw_http_client.dart';
export 'src/raw/raw_http_exception.dart';
export 'src/raw/raw_http_method.dart';
export 'src/raw/raw_http_request.dart';
export 'src/raw/raw_http_response.dart';
export 'src/raw/raw_http_streamed_response.dart';

/// Logger Interface
export 'src/utility/logger/i_net_kit_logger.dart';

/// Callback and map typedefs
export 'src/utility/typedef/request_type_def.dart';
