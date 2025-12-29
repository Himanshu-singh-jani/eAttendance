import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../models/login_request_model.dart';
import '../models/login_response_model.dart';

class LoginRemoteDataSource {
  Future<LoginResponseModel> login(LoginRequestModel request) async {
    try {
      // 🔍 REQUEST LOG
      print('=== LOGIN REQUEST START ===');
      print('URL => /UserAuth/login');
      print('REQUEST BODY => ${request.toJson()}');

      final response = await ApiClient.dio.post(
        '/UserAuth/login',
        data: request.toJson(),
      );

      // ✅ SUCCESS LOG
      print('LOGIN STATUS CODE => ${response.statusCode}');
      print('LOGIN RESPONSE BODY => ${response.data}');
      print('=== LOGIN REQUEST END ===');

      return LoginResponseModel.fromJson(response.data);

    } on DioException catch (e) {
      // ❌ ERROR LOG (MOST IMPORTANT PART)
      print('=== LOGIN ERROR ===');
      print('ERROR TYPE => ${e.type}');
      print('ERROR STATUS CODE => ${e.response?.statusCode}');
      print('ERROR RESPONSE => ${e.response?.data}');
      print('ERROR MESSAGE => ${e.message}');
      print('=== LOGIN ERROR END ===');

      // VERY IMPORTANT: rethrow so UI / provider knows login failed
      throw Exception(
        e.response?.data?['message'] ?? 'Login failed',
      );
    } catch (e) {
      // ❌ UNKNOWN ERROR
      print('=== UNKNOWN LOGIN ERROR ===');
      print(e.toString());
      throw Exception('Unexpected login error');
    }
  }
}
