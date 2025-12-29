import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/usecases/generate_qr_usecase.dart';

enum QrStatus { idle, loading, success, error }

class QrProvider extends ChangeNotifier {
  final GenerateQrUseCase generateQrUseCase;

  QrProvider(this.generateQrUseCase);

  QrStatus status = QrStatus.idle;
  String? qrImageUrl;
  String? error;

  static const _baseImageUrl =
      'https://admin.casaabuelagoa.com/images/qrimages/';

  static const _qrKey = 'qr_image_url';
  static const _qrTimeKey = 'qr_generated_at';
  static const _validHours = 24;

  // ================= PUBLIC =================

  /// 🔄 Load QR on app start / login
  Future<void> loadExistingQr() async {
    final prefs = await SharedPreferences.getInstance();

    final savedQr = prefs.getString(_qrKey);
    final savedTime = prefs.getInt(_qrTimeKey);

    if (savedQr == null || savedTime == null) {
      _clearLocal();
      return;
    }

    final generatedAt =
        DateTime.fromMillisecondsSinceEpoch(savedTime);
    final diff = DateTime.now().difference(generatedAt);

    if (diff.inHours >= _validHours) {
      await _clearPersisted();
      return;
    }

    // ✅ QR still valid
    qrImageUrl = savedQr;
    status = QrStatus.success;
    error = null;
    notifyListeners();
  }

  /// 🆕 Generate QR (SAFE)
  Future<void> generateQr() async {
    // 🔥 HARD GUARD — never regenerate if valid
    if (status == QrStatus.success && qrImageUrl != null) {
      return;
    }

    status = QrStatus.loading;
    error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('userName');

      if (username == null || username.isEmpty) {
        throw Exception('Username not found');
      }

      final result = await generateQrUseCase(username);

      qrImageUrl = _baseImageUrl + result.imageName;

      await prefs.setString(_qrKey, qrImageUrl!);
      await prefs.setInt(
        _qrTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      status = QrStatus.success;
    } catch (e) {
      error = 'Failed to generate QR';
      status = QrStatus.error;
    }

    notifyListeners();
  }

  /// ❌ Call ONLY when QR must die (admin / expiry)
  Future<void> clearQr() async {
    await _clearPersisted();
  }

  // ================= PRIVATE =================

  Future<void> _clearPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_qrKey);
    await prefs.remove(_qrTimeKey);
    _clearLocal();
  }

  void _clearLocal() {
    qrImageUrl = null;
    status = QrStatus.idle;
    error = null;
    notifyListeners();
  }
}
