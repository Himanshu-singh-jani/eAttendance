  import '../../data/datasources/qr_remote_data_source.dart';
import '../../data/models/qr_response_model.dart';

class GenerateQrUseCase {
  final QrRemoteDataSource remoteDataSource;

  GenerateQrUseCase(this.remoteDataSource);

  Future<QrResponseModel> call(String username) {
    return remoteDataSource.generateQr(username);
  }
}
