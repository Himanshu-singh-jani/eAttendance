import 'dart:async';
import 'package:barcode_generator/features/qr/presentation/providers/qr_provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:barcode_generator/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:barcode_generator/core/routes/app_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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

  // ================= LOCATION TRACKING =================
  late MapController _mapController;
  Position? _currentPosition;

  // Fixed location coordinates (CHANGE THESE TO YOUR OFFICE LOCATION)
  static const double FIXED_LATITUDE = 28.7041; // Example: Delhi
  static const double FIXED_LONGITUDE = 77.1025;
  static const double ZONE_RADIUS_METERS = 100.0;

  bool _isLoadingLocation = false;
  String _locationStatus = '';
  double? _distanceInMeters;
  bool _isInZone = false;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController(); // Initialize here
    _loadUser();
    _getCurrentLocation(); // Load location on init

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

  // ================= LOCATION METHODS =================

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationStatus = 'Getting location...';
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = 'Location services disabled';
          _isLoadingLocation = false;
        });
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatus = 'Location permission denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus = 'Location permission permanently denied';
          _isLoadingLocation = false;
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Calculate distance
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        FIXED_LATITUDE,
        FIXED_LONGITUDE,
      );

      setState(() {
        _currentPosition = position;
        _distanceInMeters = distance;
        _isInZone = distance <= ZONE_RADIUS_METERS;
        _isLoadingLocation = false;

        if (_isInZone) {
          _locationStatus = '✓ In Zone (${distance.toStringAsFixed(0)}m)';
        } else {
          _locationStatus = '✗ Out of Zone (${distance.toStringAsFixed(0)}m)';
        }

        // Center map only if it's already ready
        if (_isMapReady) {
          _centerMapOnLocations();
        }
      });
    } catch (e) {
      setState(() {
        _locationStatus = 'Error: $e';
        _isLoadingLocation = false;
      });
    }
  }

  void _centerMapOnLocations() {
    if (_currentPosition != null && mounted && _isMapReady) {
      // Add a small delay to ensure map is ready
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted || !_isMapReady) return;

        try {
          // Calculate bounds to show both locations
          final bounds = LatLngBounds(
            LatLng(
              _currentPosition!.latitude < FIXED_LATITUDE
                  ? _currentPosition!.latitude
                  : FIXED_LATITUDE,
              _currentPosition!.longitude < FIXED_LONGITUDE
                  ? _currentPosition!.longitude
                  : FIXED_LONGITUDE,
            ),
            LatLng(
              _currentPosition!.latitude > FIXED_LATITUDE
                  ? _currentPosition!.latitude
                  : FIXED_LATITUDE,
              _currentPosition!.longitude > FIXED_LONGITUDE
                  ? _currentPosition!.longitude
                  : FIXED_LONGITUDE,
            ),
          );

          // Fit bounds with padding
          _mapController.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
          );
        } catch (e) {
          // Map controller not ready yet, ignore
          debugPrint('Map controller error: $e');
        }
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    try {
      _mapController.dispose();
    } catch (e) {
      // Already disposed
    }
    super.dispose();
  }

  // ================= HELPERS =================

  String _formatTime(DateTime d) {
    return "${d.hour > 12 ? d.hour - 12 : d.hour}:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}";
  }

  String get time => _formatTime(now);

  String get date =>
      "${now.day} ${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][now.month - 1]}, ${now.year}";

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
              const Text(
                'Profile',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
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
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
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
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Attendance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Start Time',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ================= PUNCH IN =================
                          if (attendanceState == HomeAttendanceState.idle) ...[
                            // ===== OPENSTREETMAP =====
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isInZone ? Colors.green : Colors.red,
                                  width: 2,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: _isLoadingLocation
                                        ? const Center(
                                            child: CircularProgressIndicator(),
                                          )
                                        : _currentPosition == null
                                        ? Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Icons.location_off,
                                                  size: 40,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(_locationStatus),
                                                const SizedBox(height: 8),
                                                TextButton.icon(
                                                  onPressed:
                                                      _getCurrentLocation,
                                                  icon: const Icon(
                                                    Icons.refresh,
                                                  ),
                                                  label: const Text('Retry'),
                                                ),
                                              ],
                                            ),
                                          )
                                        : FlutterMap(
                                            mapController: _mapController,
                                            options: MapOptions(
                                              initialCenter: LatLng(
                                                _currentPosition!.latitude,
                                                _currentPosition!.longitude,
                                              ),
                                              initialZoom: 15,
                                              onMapReady: () {
                                                setState(() {
                                                  _isMapReady = true;
                                                });
                                                _centerMapOnLocations();
                                              },
                                            ),
                                            children: [
                                              // OpenStreetMap Tiles (FREE!)
                                              TileLayer(
                                                urlTemplate:
                                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                                userAgentPackageName:
                                                    'com.example.barcode_generator',
                                              ),

                                              // Zone Circle
                                              CircleLayer(
                                                circles: [
                                                  CircleMarker(
                                                    point: const LatLng(
                                                      FIXED_LATITUDE,
                                                      FIXED_LONGITUDE,
                                                    ),
                                                    radius: ZONE_RADIUS_METERS,
                                                    useRadiusInMeter: true,
                                                    color: Colors.green
                                                        .withOpacity(0.2),
                                                    borderColor: Colors.green,
                                                    borderStrokeWidth: 2,
                                                  ),
                                                ],
                                              ),

                                              // Markers
                                              MarkerLayer(
                                                markers: [
                                                  // Current Location (Blue)
                                                  Marker(
                                                    point: LatLng(
                                                      _currentPosition!
                                                          .latitude,
                                                      _currentPosition!
                                                          .longitude,
                                                    ),
                                                    width: 40,
                                                    height: 40,
                                                    child: const Icon(
                                                      Icons.location_on,
                                                      color: Colors.blue,
                                                      size: 40,
                                                    ),
                                                  ),
                                                  // Office Location (Red)
                                                  Marker(
                                                    point: const LatLng(
                                                      FIXED_LATITUDE,
                                                      FIXED_LONGITUDE,
                                                    ),
                                                    width: 40,
                                                    height: 40,
                                                    child: const Icon(
                                                      Icons.business,
                                                      color: Colors.red,
                                                      size: 40,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                  ),

                                  // Location Status Overlay
                                  if (_currentPosition != null)
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _isInZone
                                              ? Colors.green
                                              : Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _isInZone
                                                  ? Icons.check_circle
                                                  : Icons.warning,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _locationStatus,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Refresh Button
                                  if (_currentPosition != null)
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: FloatingActionButton.small(
                                        onPressed: _getCurrentLocation,
                                        backgroundColor: Colors.white,
                                        child: const Icon(
                                          Icons.my_location,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Warning message if not in zone
                            if (_currentPosition != null && !_isInZone)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.red.shade700,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'You are not in the zone! Please move closer to the office location.',
                                        style: TextStyle(
                                          color: Colors.red.shade900,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 24),
                            GestureDetector(
                              onTap: _isInZone
                                  ? () {
                                      setState(() {
                                        punchInTime = _formatTime(
                                          DateTime.now(),
                                        );
                                        punchOutTime = null;
                                        attendanceState =
                                            HomeAttendanceState.punchedIn;
                                      });
                                    }
                                  : null,
                              child: Opacity(
                                opacity: _isInZone ? 1.0 : 0.5,
                                child: Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    color: _isInZone
                                        ? Colors.green
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.touch_app,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Punch In',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
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
                                onPressed: qrProvider.status == QrStatus.loading
                                    ? null
                                    : () => context
                                          .read<QrProvider>()
                                          .generateQr(),
                                child: qrProvider.status == QrStatus.loading
                                    ? const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      )
                                    : const Text('Generate QR'),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (qrProvider.status == QrStatus.success &&
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
                                          punchOutTime = _formatTime(
                                            DateTime.now(),
                                          );
                                          attendanceState =
                                              HomeAttendanceState.idle;
                                        });
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Punch Out'),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _timeColumn(
                                'Punch In',
                                punchInTime ?? '-- : --',
                                Colors.green,
                              ),
                              _timeColumn(
                                'Punch Out',
                                punchOutTime ?? '-- : --',
                                Colors.red,
                              ),
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
