/**
 * Synthetic Dart sources for analyzer tests. Generic names only
 * (example_app, api.example.com, storage.example.com, test-token).
 */

export const PUBSPEC_V6 = `name: example_app
environment:
  sdk: ^3.5.0
dependencies:
  flutter:
    sdk: flutter
  net_kit: ^6.0.0-dev.1
`;

export const PUBSPEC_V5 = `name: example_app
dependencies:
  net_kit: ^5.4.1
`;

export const LOCK_V6 = `packages:
  net_kit:
    dependency: "direct main"
    description:
      name: net_kit
    source: hosted
    version: "6.0.0-dev.1"
`;

export const GOOD_AUTH = `
import 'package:flutter/foundation.dart';
import 'package:net_kit/net_kit.dart';

final manager = NetKitManager(
  baseUrl: 'https://api.example.com',
  refreshTokenPath: '/auth/refresh',
  devMode: kDebugMode,
  onSessionInvalidated: (exception) => auth.signOut(),
);

Future<void> login(String email, String password) async {
  final session = await manager.requestModel<SessionModel>(
    path: '/auth/login',
    method: RequestMethod.post,
    model: const SessionModel(),
    body: {'email': email, 'password': password},
    authPolicy: AuthPolicy.none,
  );
  manager
    ..setAccessToken(session.accessToken)
    ..setRefreshToken(session.refreshToken);
}

Future<UserModel> me() => manager.requestModel<UserModel>(
      path: '/me',
      method: RequestMethod.get,
      model: const UserModel(),
      authPolicy: AuthPolicy.required,
    );

Future<void> load() async {
  try {
    await me();
  } on ApiException catch (error) {
    if (error.type == ApiFailureType.sessionInvalidated) {
      await auth.logout();
      return;
    }
    showError(error);
  }
}

Future<void> onLogoutPressed() async {
  await auth.logout();
}
`;

export const BAD_AUTH = `
import 'package:net_kit/net_kit.dart';

final manager = NetKitManager(
  baseUrl: 'http://api.example.com',
  refreshTokenPath: '/auth/refresh',
  allowCrossOriginRequests: true,
  devMode: true,
  logResponseBodies: true,
);

Future<void> profile() => manager.requestVoid(
      path: '/me',
      method: RequestMethod.get,
      authPolicy: AuthPolicy.none,
    );

Future<void> partner() => manager.requestVoid(
      path: 'https://partner.example.org/v1/ping',
      method: RequestMethod.get,
      authPolicy: AuthPolicy.required,
    );

Future<void> loadTransient() async {
  try {
    await profile();
  } on ApiException catch (e) {
    if (e.type == ApiFailureType.transport || e.fromRefresh) {
      await auth.logout();
    }
  }
}

Future<void> loadCatchAll() async {
  try {
    await profile();
  } catch (e) {
    await signOut();
  }
}

Future<void> loadAny401() async {
  try {
    await profile();
  } on ApiException catch (e) {
    if (e.statusCode == 401) logout();
  }
}
`;

export const SIGNED_UPLOAD_BAD = `
import 'dart:io';
import 'package:net_kit/net_kit.dart';

class UploadService {
  UploadService(this.manager);
  final NetKitManager manager;

  void cancelUpload() {}

  Future<void> upload(SignedUpload signed, File file) async {
    final bytes = await file.readAsBytes();
    await manager.uploadRawData<VoidModel>(
      path: signed.url,
      model: VoidModel(),
      data: bytes,
      method: RequestMethod.put,
    );
    await manager.transport.send(
      RawHttpRequest(
        uri: Uri.parse('https://storage.example.com/bucket/a.pdf?X-Goog-Signature=abc123'),
        method: RawHttpMethod.put,
        headers: {'Authorization': 'Bearer test-token', 'Content-Type': 'application/pdf'},
        body: BytesRawHttpBody(bytes),
      ),
    );
  }

  Future<void> uploadVideo(File file) async {
    await manager.uploadFile<VoidModel>(
      path: '/videos/1',
      model: VoidModel(),
      filePath: file.path,
      method: RequestMethod.put,
    );
    await manager.transport.send(
      RawHttpRequest(
        uri: Uri.parse(uploadUrl),
        method: RawHttpMethod.put,
        body: StreamRawHttpBody(stream: file.openRead(), contentLength: await file.length()),
      ),
    );
  }
}
`;

export const SIGNED_UPLOAD_GOOD = `
import 'dart:io';
import 'package:net_kit/net_kit.dart';

class UploadService {
  UploadService(this.manager);
  final NetKitManager manager;
  NetKitCancellationToken? _token;

  void cancelUpload() => _token?.cancel();

  Future<void> upload(File file) async {
    final signed = await manager.requestModel<SignedUploadModel>(
      path: '/uploads/sign',
      method: RequestMethod.post,
      model: const SignedUploadModel(),
      body: {'fileName': 'report.pdf'},
    );
    final token = _token = NetKitCancellationToken();
    final response = await manager.transport.send(
      RawHttpRequest(
        uri: Uri.parse(signed.url),
        method: RawHttpMethod.put,
        headers: signed.headers,
        body: FileRawHttpBody(file.path),
        cancellationToken: token,
      ),
    );
    if (!response.isSuccessful) throw StateError('storage');
  }

  Future<void> apiUpload(File file, NetKitCancellationToken token) =>
      manager.uploadFile<VoidModel>(
        path: '/documents/1',
        model: VoidModel(),
        filePath: file.path,
        method: RequestMethod.put,
        cancellationToken: token,
      );

  Future<void> smallAvatar(List<int> pickedBytes) => manager.uploadRawData<VoidModel>(
        path: '/me/avatar',
        model: VoidModel(),
        data: pickedBytes,
        method: RequestMethod.put,
      );
}
`;

export const STREAMING_BAD = `
import 'dart:io';
import 'package:net_kit/net_kit.dart';

Future<void> downloadVideo(RawHttpClient client, String url, String target) async {
  final response = await client.send(
    RawHttpRequest(uri: Uri.parse(url), method: RawHttpMethod.get),
  );
  await File(target).writeAsBytes(response.bodyBytes);
}
`;

export const STREAMING_GOOD = `
import 'dart:convert';
import 'dart:io';
import 'package:net_kit/net_kit.dart';

Future<void> downloadVideo(RawHttpClient client, String url, String target) async {
  final response = await client.sendStreamed(
    RawHttpRequest(uri: Uri.parse(url), method: RawHttpMethod.get),
  );
  if (!response.isSuccessful) return;
  await response.body.pipe(File(target).openWrite());
}

Future<Map<String, dynamic>> status(RawHttpClient client) async {
  final response = await client.send(
    RawHttpRequest(uri: Uri.parse('https://status.example.com/v1'), method: RawHttpMethod.get),
  );
  return jsonDecode(response.bodyText) as Map<String, dynamic>;
}
`;

export const LEGACY_V5 = `
import 'package:net_kit/net_kit.dart';

final manager = NetKitManager(
  baseUrl: 'https://api.example.com',
  baseOptions: BaseOptions(headers: {'Accept': 'application/json'}),
  testMode: true,
  onRefreshFailed: ({required statusCode, required exception}) => logout(),
);

Future<void> a(CancelToken token) => manager.requestVoid(
      path: '/x',
      method: RequestMethod.get,
      containsAccessToken: false,
      skipTokenRefresh: true,
      cancelToken: token,
      options: Options(headers: {'X-Trace': '1'}),
    );

Future<void> b() => manager.uploadFormData<VoidModel>(
      path: '/f',
      model: VoidModel(),
      method: RequestMethod.post,
      formData: FormData.fromMap({'a': 1}),
    );

void c() {
  try {
    a(CancelToken());
  } on DioException catch (e) {
    print(e);
  }
}

final raw = DioRawHttpClient();
`;

export const DIO_DIRECT = `
import 'package:dio/dio.dart';
import 'package:net_kit/net_kit.dart';

class Api {
  Api(this.manager);
  final NetKitManager manager;
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));

  Future<void> me() => dio.get<dynamic>('/me');
}
`;

export const DIO_ONLY = `
import 'package:dio/dio.dart';

final analytics = Dio(BaseOptions(baseUrl: 'https://metrics.example.com'));
Future<void> track() => analytics.post<dynamic>('/events', data: {'e': 1});
`;

export const LOGGING_GOOD = `
import 'package:flutter/foundation.dart';
import 'package:net_kit/net_kit.dart';

final manager = NetKitManager(
  baseUrl: 'https://api.example.com',
  refreshTokenPath: '/auth/refresh',
  devMode: kDebugMode,
  onSessionInvalidated: (_) => auth.signOut(),
  interceptors: [
    RedactingLogInterceptor(logBodies: true, bodySanitizer: maskTokens),
  ],
);
`;

export const LOGGING_BAD = `
import 'package:net_kit/net_kit.dart';

final manager = NetKitManager(
  baseUrl: 'https://api.example.com',
  headers: {'X-Api-Key': 'abcd1234secretvalue'},
  interceptors: [RedactingLogInterceptor(logBodies: true)],
);
`;

export const LEXER_TRAPS = `
import 'package:net_kit/net_kit.dart';

// manager.uploadRawData(path: signedUrl, data: await file.readAsBytes());
/* NetKitManager(allowCrossOriginRequests: true) */
const doc = 'manager.requestVoid(path: "https://storage.example.com/x?X-Amz-Signature=1", authPolicy: AuthPolicy.required)';
const raw = r'NetKitManager(devMode: true)';
const nested = 'value \${map['NetKitManager(logResponseBodies: true)']} end';
const multi = '''
  NetKitManager(baseUrl: 'http://api.example.com')
''';
`;
