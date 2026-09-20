import 'package:dio/dio.dart';

import 'app_logger.dart';

/// Loguea cada request, respuesta y error de Dio con formato.
class DioLoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    logger.d('→ ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    logger.d('← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final req = err.requestOptions;
    logger.e(
      '✗ ${req.method} ${req.uri} → ${err.response?.statusCode ?? err.type.name}',
      error: err,
      stackTrace: err.stackTrace,
    );
    handler.next(err);
  }
}
