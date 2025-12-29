import 'dart:async';
import 'package:barcode_generator/features/qr/presentation/providers/qr_provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:barcode_generator/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:barcode_generator/core/routes/app_router.dart';

enum HomeAttendanceState { idle, punchedIn }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String userName = 'User';
  String fullName = '';
  String email = '';
  String orgName = '';
  String officeName = '';
  String mobileNo = '';

  String? punchInTime;
  String? punchOutTime;

  HomeAttendanceState attendanceState = HomeAttendanceState.idle;

  late Timer _timer;
  DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadUser();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => now = DateTime.now());
    });

    // 🔥 Restore QR (24h logic)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QrProvider>().loadExistingQr();
    });
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? 'User';
      fullName = prefs.getString('fullName') ?? '';
      email = prefs.getString('email') ?? '';
      orgName = prefs.getString('orgName') ?? '';
      officeName = prefs.getString('officeName') ?? '';
      mobileNo = prefs.getString('mobileNo') ?? '';
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // ================= HELPERS =================

  String _formatTime(DateTime d) {
    return "${d.hour > 12 ? d.hour - 12 : d.hour}:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}";
  }

  String get time => _formatTime(now);

  String get date =>
      "${now.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][now.month - 1]}, ${now.year}";

  // ================= LOGOUT =================

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('token');
    await prefs.remove('userName');
    await prefs.remove('fullName');
    await prefs.remove('email');
    await prefs.remove('orgName');
    await prefs.remove('officeName');
    await prefs.remove('mobileNo');

    if (!mounted) return;

    Navigator.of(context).pop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go(AppRoutes.login);
      }
    });
  }

  // ================= PROFILE SHEET =================

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Profile',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _row('Full Name', fullName),
              _row('Username', userName),
              _row('Organization', orgName),
              _row('Office', officeName),
              _row('Email', email),
              _row('Mobile', mobileNo),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Logout'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child:
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value.isNotEmpty ? value : '-')),
        ],
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final qrProvider = context.watch<QrProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFFCF4EE),
      body: SafeArea(
        child: Column(
          children: [
            // ===== TOP BAR =====
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _showProfileSheet,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.person,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(height: 4),
                        Text(userName,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Attendance',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text('Start Time',
                              style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 6),
                          Text(time,
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),

                          // ================= PUNCH IN =================
                          if (attendanceState == HomeAttendanceState.idle) ...[
                            Container(
                              height: 120,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('Map Placeholder'),
                            ),
                            const SizedBox(height: 24),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  punchInTime =
                                      _formatTime(DateTime.now());
                                  punchOutTime = null;
                                  attendanceState =
                                      HomeAttendanceState.punchedIn;
                                });
                              },
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.touch_app,
                                        color: Colors.white, size: 28),
                                    SizedBox(height: 6),
                                    Text('Punch In',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                                FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // ================= QR + PUNCH OUT =================
                          if (attendanceState ==
                              HomeAttendanceState.punchedIn) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed:
                                    qrProvider.status ==
                                            QrStatus.loading
                                        ? null
                                        : () => context
                                            .read<QrProvider>()
                                            .generateQr(),
                                child: qrProvider.status ==
                                        QrStatus.loading
                                    ? const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      )
                                    : const Text('Generate QR'),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (qrProvider.status ==
                                    QrStatus.success &&
                                qrProvider.qrImageUrl != null)
                              Image.network(
                                qrProvider.qrImageUrl!,
                                height: 220,
                              ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: punchOutTime == null
                                    ? () {
                                        setState(() {
                                          punchOutTime =
                                              _formatTime(
                                                  DateTime.now());
                                          attendanceState =
                                              HomeAttendanceState
                                                  .idle;
                                        });
                                      }
                                    : null,
                                style:
                                    ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppColors.primary,
                                  foregroundColor:
                                      Colors.white,
                                ),
                                child:
                                    const Text('Punch Out'),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              _timeColumn('Punch In',
                                  punchInTime ?? '-- : --',
                                  Colors.green),
                              _timeColumn('Punch Out',
                                  punchOutTime ?? '-- : --',
                                  Colors.red),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeColumn(String label, String time, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(time,
            style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
