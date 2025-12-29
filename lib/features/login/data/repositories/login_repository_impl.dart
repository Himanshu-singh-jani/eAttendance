import 'package:barcode_generator/repositories/login_repository.dart';


import '../datasources/login_remote_datasource.dart';
import '../models/login_request_model.dart';
import '../models/login_response_model.dart';

class LoginRepositoryImpl implements LoginRepository {
  final LoginRemoteDataSource remoteDataSource;

  LoginRepositoryImpl(this.remoteDataSource);

  @override
  Future<LoginResponseModel> login(LoginRequestModel request) {
    return remoteDataSource.login(request);
  }
}
