import 'package:dio/dio.dart';

import 'app_logger.dart';

/// Loguea los errores de Dio. Las requests exitosas no: el poll de chat y
/// combate llenaría el log. Nunca la URL del reader ni sus ids (ver
/// AGENTS.md): solo método y estado.
class DioLoggingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    logger.e(
      '✗ ${err.requestOptions.method} → '
      '${err.response?.statusCode ?? err.type.name}',
      stackTrace: err.stackTrace,
    );
    handler.next(err);
  }
}
