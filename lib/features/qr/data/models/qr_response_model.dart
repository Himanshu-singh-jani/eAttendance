class QrResponseModel {
  final String imageName;

  QrResponseModel({required this.imageName});

  factory QrResponseModel.fromJson(Map<String, dynamic> json) {
    final message = json['message'] as String;

    
    final imageName = message.split('Path :').last.trim();

    return QrResponseModel(imageName: imageName);
  }
}
        