import '../../../../core/network/api_client.dart';
import '../models/qr_response_model.dart';

class QrRemoteDataSource {
  Future<QrResponseModel> generateQr(String username) async {
    final response = await ApiClient.dio.post(
      '/Attendance/GenerateAndSendQr/$username',
    );

    return QrResponseModel.fromJson(response.data);
  }
}
  