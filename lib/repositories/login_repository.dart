import 'package:barcode_generator/features/login/data/models/login_request_model.dart';
import 'package:barcode_generator/features/login/data/models/login_response_model.dart';

abstract class LoginRepository {
  Future<LoginResponseModel> login(LoginRequestModel request);
}
