import 'package:barcode_generator/repositories/login_repository.dart';

import '../../data/models/login_request_model.dart';
import '../../data/models/login_response_model.dart';

class LoginUseCase {
  final LoginRepository repository;

  LoginUseCase(this.repository);

  Future<LoginResponseModel> call(
    String username,
    String password,
  ) {
    return repository.login(
      LoginRequestModel(username: username, password: password),
    );
  }
}
