import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Internal Imports
import 'package:barcode_generator/features/qr/presentation/providers/qr_provider.dart';
import 'package:barcode_generator/theme/app_colors.dart';
import 'package:barcode_generator/core/routes/app_router.dart';

enum HomeAttendanceState { idle, punchedIn }
enum AttendanceTab { today, list }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ====== GEOFENCING CONFIG ======
  static const double OFFICE_LAT = 28.7041; 
  static const double OFFICE_LNG = 77.1025;
  static const double ZONE_RADIUS_METERS = 100;

  // ====== MAP + ZONE STATE ======
  late MapController _mapController;
  bool _isMapReady = false;
  Position? _currentPosition;
  double? _distanceInMeters;
  bool _isInZone = false;

  // ====== DATA ======
  String userName = '', fullName = '', email = '', orgName = '', officeName = '', mobileNo = '';
  String? punchInTime;
  String? punchOutTime;
  DateTime? punchInDateTime;
  String? lastTotalWorkingTime;
  double? punchInDistance; // Added to track distance during punch-in
  List<Map<String, dynamic>> attendanceHistory = [];

  String _currentAddress = "Fetching location...";
  bool _isLocationLoading = true;
  bool _isOutOfZone = false;

  HomeAttendanceState attendanceState = HomeAttendanceState.idle;
  AttendanceTab selectedTab = AttendanceTab.today;

  late Timer _timer;
  DateTime now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadAllStoredData();
    _getCurrentLocation();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QrProvider>().loadExistingQr();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // ================= DATA LOADING =================

  Future<void> _loadAllStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? 'User';
      fullName = prefs.getString('fullName') ?? '';
      email = prefs.getString('email') ?? '';
      orgName = prefs.getString('orgName') ?? '';
      officeName = prefs.getString('officeName') ?? '';
      mobileNo = prefs.getString('mobileNo') ?? '';

      punchInTime = prefs.getString('punchInTime');
      punchOutTime = prefs.getString('punchOutTime');
      lastTotalWorkingTime = prefs.getString('lastTotalWorkingTime');
      punchInDistance = prefs.getDouble('punchInDistance');

      String? savedInDT = prefs.getString('punchInDateTime');
      if (savedInDT != null) punchInDateTime = DateTime.parse(savedInDT);

      bool isPunchedIn = prefs.getBool('isPunchedIn') ?? false;
      attendanceState = isPunchedIn ? HomeAttendanceState.punchedIn : HomeAttendanceState.idle;

      String? historyRaw = prefs.getString('attendanceHistory');
      if (historyRaw != null) {
        attendanceHistory = List<Map<String, dynamic>>.from(json.decode(historyRaw));
      }
    });
  }

  // ================= LOCATION LOGIC =================

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocationLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _currentAddress = "Location services disabled";
          _isLocationLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _currentAddress = "Permission denied";
            _isLocationLoading = false;
          });
          return;
        }
      }

      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      double distance = Geolocator.distanceBetween(pos.latitude, pos.longitude, OFFICE_LAT, OFFICE_LNG);
      List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      Placemark place = placemarks[0];

      setState(() {
        _currentPosition = pos;
        _distanceInMeters = distance;
        _isInZone = distance <= ZONE_RADIUS_METERS;
        _isOutOfZone = !_isInZone;
        _currentAddress = "${place.street}, ${place.locality}, ${place.postalCode}";
        _isLocationLoading = false;
      });

      if (_isMapReady) {
        _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
      }
    } catch (e) {
      setState(() {
        _currentAddress = "Location error";
        _isLocationLoading = false;
      });
    }
  }

  // ================= STORAGE HELPERS =================

  Future<void> _savePunchIn(String time, DateTime fullDateTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('punchInTime', time);
    await prefs.setString('punchInDateTime', fullDateTime.toIso8601String());
    await prefs.setBool('isPunchedIn', true);
    
    // Save current distance during punch in
    double currentDist = _distanceInMeters ?? 0.0;
    await prefs.setDouble('punchInDistance', currentDist);
    
    await prefs.remove('punchOutTime');
    await prefs.remove('lastTotalWorkingTime');
  }

  Future<void> _savePunchOut(String time) async {
    final prefs = await SharedPreferences.getInstance();
    String workTime = _calculateFinalWorkTime();

    await prefs.setString('punchOutTime', time);
    await prefs.setBool('isPunchedIn', false);
    await prefs.setString('lastTotalWorkingTime', workTime);

    Map<String, dynamic> newRecord = {
      'date': "${now.day} ${_getMonth(now.month)}, ${now.year}",
      'in': punchInTime,
      'out': time,
      'total': workTime,
      'distance': _distanceInMeters?.toStringAsFixed(0), // Added distance to history
    };

    attendanceHistory.insert(0, newRecord);
    if (attendanceHistory.length > 5) attendanceHistory.removeLast();
    await prefs.setString('attendanceHistory', json.encode(attendanceHistory));
  }

  // ================= HELPERS =================

  String _formatTime(DateTime d) {
    return "${d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour)}:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}";
  }

  String _getWorkingTime() {
    if (attendanceState == HomeAttendanceState.punchedIn && punchInDateTime != null) {
      Duration diff = now.difference(punchInDateTime!);
      return _durationToString(diff);
    }
    return lastTotalWorkingTime ?? "00:00:00";
  }

  String _calculateFinalWorkTime() {
    if (punchInDateTime == null) return "00:00:00";
    Duration diff = now.difference(punchInDateTime!);
    return _durationToString(diff);
  }

  String _durationToString(Duration duration) {
    String hours = duration.inHours.toString().padLeft(2, '0');
    String minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  String _getMonth(int m) => ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    if (!mounted) return;
    Navigator.of(context).pop();
    context.go(AppRoutes.login);
  }

  // ================= UI MAIN ==================

  @override
  Widget build(BuildContext context) {
    final qrProvider = context.watch<QrProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFFCF4EE),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildTabs(),
            Expanded(
              child: selectedTab == AttendanceTab.today
                  ? _todayAttendanceUI(qrProvider)
                  : _attendanceListUI(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Stack(
        children: [
          const Align(
            alignment: Alignment.topCenter,
            child: Text('eAttendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: GestureDetector(
              onTap: _showProfileSheet,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.person, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const Text('UI/UX Developer', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _tabButton('_today eAttendance', AttendanceTab.today),
          _tabButton('eAttendance List', AttendanceTab.list),
        ],
      ),
    );
  }

  Widget _todayAttendanceUI(QrProvider qrProvider) {
    return RefreshIndicator(
      onRefresh: _getCurrentLocation,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${now.day} ${_getMonth(now.month)}, ${now.year}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (_currentPosition != null)
              Container(
                height: 200,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isInZone ? Colors.green : Colors.red,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      initialZoom: 15,
                      onMapReady: () => _isMapReady = true,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.barcode_generator',
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: const LatLng(OFFICE_LAT, OFFICE_LNG),
                            radius: ZONE_RADIUS_METERS,
                            useRadiusInMeter: true,
                            color: Colors.green.withOpacity(0.2),
                            borderColor: Colors.green,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            width: 40, height: 40,
                            child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
                          ),
                          const Marker(
                            point: LatLng(OFFICE_LAT, OFFICE_LNG),
                            width: 40, height: 40,
                            child: Icon(Icons.business, color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            if (!_isLocationLoading && _isOutOfZone) _buildWarningBanner(),
            _buildMainAttendanceCard(qrProvider),
            const SizedBox(height: 20),
            ...attendanceHistory.map((item) => _historyCard(item)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "OUTSIDE office zone (${_distanceInMeters?.toStringAsFixed(0)}m away).",
              style: const TextStyle(fontSize: 13, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainAttendanceCard(QrProvider qrProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('Current Time', style: TextStyle(color: Colors.grey)),
          Text(_formatTime(now), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          if (attendanceState == HomeAttendanceState.idle) ...[
            _buildLocationStatus(),
            const SizedBox(height: 24),
            _buildPunchButton(true),
          ] else ...[
            const Text("You are Punched In", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildQrSection(qrProvider),
            const SizedBox(height: 20),
            _buildPunchButton(false),
          ],
          
          const SizedBox(height: 24),
          _buildTimeSummaryRow(),
        ],
      ),
    );
  }

  Widget _buildLocationStatus() {
    return Column(
      children: [
        _isLocationLoading
            ? const CircularProgressIndicator()
            : Column(
                children: [
                  Icon(Icons.location_on, color: _isInZone ? Colors.green : Colors.orange, size: 40),
                  Text(_isInZone ? "Location Verified" : "Outside Office Zone",
                      style: TextStyle(color: _isInZone ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                ],
              ),
        const SizedBox(height: 8),
        Text(_currentAddress, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildTimeSummaryRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _timeColumn('Punch In', punchInTime ?? '-- : --', Colors.green),
        _timeColumn('Working Time', _getWorkingTime(), Colors.blue),
        _timeColumn('Punch Out', punchOutTime ?? '-- : --', Colors.red),
      ],
    );
  }

  Widget _buildPunchButton(bool isPunchIn) {
    return GestureDetector(
      onTap: () async {
        DateTime nowDT = DateTime.now();
        String timeStr = _formatTime(nowDT);

        if (isPunchIn) {
          // Perform location refresh just before punching in to get accurate distance
          await _getCurrentLocation();
          await _savePunchIn(timeStr, nowDT);

          setState(() {
            punchInDateTime = nowDT;
            punchInTime = timeStr;
            punchInDistance = _distanceInMeters;
            punchOutTime = null;
            lastTotalWorkingTime = null;
            attendanceState = HomeAttendanceState.punchedIn;
          });
        } else {
          String finalTime = _calculateFinalWorkTime();
          await _savePunchOut(timeStr);
          setState(() {
            punchOutTime = timeStr;
            lastTotalWorkingTime = finalTime;
            attendanceState = HomeAttendanceState.idle;
          });
        }
      },
      child: Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          color: isPunchIn ? Colors.green : AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isPunchIn ? Icons.touch_app : Icons.logout, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(isPunchIn ? 'Punch In' : 'Punch Out',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildQrSection(QrProvider qrProvider) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity, height: 44,
          child: ElevatedButton(
            onPressed: qrProvider.status == QrStatus.loading ? null : () => context.read<QrProvider>().generateQr(),
            child: qrProvider.status == QrStatus.loading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Text('Generate QR Code'),
          ),
        ),
        if (qrProvider.qrImageUrl != null) ...[
          const SizedBox(height: 12),
          Image.network(qrProvider.qrImageUrl!, height: 180),
        ],
      ],
    );
  }

  void _showProfileSheet() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Profile Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),

          _profileRow('Username', userName),
          _profileRow('Full Name', fullName),
          _profileRow('Email', email),
          _profileRow('Mobile', mobileNo),
          _profileRow('Organization', orgName),
          _profileRow('Office', officeName),

          const SizedBox(height: 28),

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
    ),
  );
}

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['date'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text("In: ${data['in']} | Out: ${data['out']}", style: const TextStyle(fontWeight: FontWeight.w600)),
              if (data['distance'] != null)
                 Text("Distance: ${data['distance']}m", style: const TextStyle(fontSize: 11, color: Colors.orange)),
            ],
          ),
          Text(data['total'], style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _tabButton(String label, AttendanceTab tab) {
    bool isSel = selectedTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSel ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: isSel ? Colors.white : Colors.black54, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _timeColumn(String label, String time, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text(time, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _attendanceListUI() => const Center(child: Text('Attendance History Screen'));
}