import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Ubah dengan: flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api/v1
/// Otomatis memakai 10.0.2.2 di Android emulator dan localhost di Desktop/iOS/Web.
const String _envApiUrl = String.fromEnvironment('API_BASE_URL');

String get apiBaseUrl {
  if (_envApiUrl.isNotEmpty) return _envApiUrl;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000/api/v1';
  }
  return 'http://localhost:8000/api/v1';
}

const _secureStorage = FlutterSecureStorage();
const tokenKey = 'access_token';
String? _memToken;

Future<String?> readToken() async {
  try {
    return await _secureStorage.read(key: tokenKey) ?? _memToken;
  } catch (_) {
    return _memToken;
  }
}

Future<void> writeToken(String token) async {
  _memToken = token;
  try {
    await _secureStorage.write(key: tokenKey, value: token);
  } catch (_) {}
}

Future<void> deleteToken() async {
  _memToken = null;
  try {
    await _secureStorage.delete(key: tokenKey);
  } catch (_) {}
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
    final token = await readToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }));
  return dio;
});

/// Ambil pesan error ramah dari respons FastAPI ({"detail": ...}).
String errMsg(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      return 'Input tidak valid';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Tidak dapat terhubung ke server';
    }
  }
  return 'Terjadi kesalahan';
}
