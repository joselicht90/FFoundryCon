import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/dio_logging_interceptor.dart';
import 'reader_url_provider.dart';

/// Construye un [Dio] con timeouts y headers sensatos para una base dada.
Dio buildDio(String baseUrl) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 8),
      headers: {'Content-Type': 'application/json'},
      responseType: ResponseType.json,
    ),
  );
  dio.interceptors.add(DioLoggingInterceptor());
  return dio;
}

/// Cliente HTTP principal. Se reconstruye cuando cambia la URL del reader.
final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(readerUrlProvider) ?? '';
  final dio = buildDio(baseUrl);
  ref.onDispose(dio.close);
  return dio;
});
