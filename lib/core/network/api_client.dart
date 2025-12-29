import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Content-Type': 'application/json',
        'accept': '*/*',
      },
    ),
  )..interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );

  static String get _baseUrl {
    if (kReleaseMode) {
      return 'https://casaabuelagoa.com/api'; // PROD
    } else {
      return 'https://casaabuelagoa.com/api'; 
    }
  }
}
