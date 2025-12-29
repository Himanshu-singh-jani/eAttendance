// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../../theme/app_colors.dart';

// class ProfileActionWidget extends StatefulWidget {
//   const ProfileActionWidget({super.key});

//   @override
//   State<ProfileActionWidget> createState() => _ProfileActionWidgetState();
// }

// class _ProfileActionWidgetState extends State<ProfileActionWidget> {
//   String userName = '';
//   String fullName = '';
//   String orgName = '';
//   String officeName = '';
//   String email = '';
//   String mobileNo = '';

//   @override
//   void initState() {
//     super.initState();
//     _loadProfile();
//   }

//   Future<void> _loadProfile() async {
//     final prefs = await SharedPreferences.getInstance();
//     if (!mounted) return;

//     setState(() {
//       userName = prefs.getString('userName') ?? '';
//       fullName = prefs.getString('fullName') ?? '';
//       orgName = prefs.getString('orgName') ?? '';
//       officeName = prefs.getString('officeName') ?? '';
//       email = prefs.getString('email') ?? '';
//       mobileNo = prefs.getString('mobileNo') ?? '';
//     });
//   }

//   /// 🔐 LOGOUT (QR-safe + correct snackbar)
//   Future<void> _logout() async {
//     final prefs = await SharedPreferences.getInstance();

//     // Remove auth + user only (keep QR)
//     await prefs.remove('isLoggedIn');
//     await prefs.remove('token');
//     await prefs.remove('expiresAt');

//     await prefs.remove('userId');
//     await prefs.remove('userName');
//     await prefs.remove('role');
//     await prefs.remove('orgId');
//     await prefs.remove('orgName');
//     await prefs.remove('officeId');
//     await prefs.remove('officeName');
//     await prefs.remove('fullName');
//     await prefs.remove('email');
//     await prefs.remove('mobileNo');

//     if (!mounted) return;

//     // Close bottom sheet
//     Navigator.of(context).pop();

//     // Show logout success snackbar
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text('Logged out successfully'),
//         backgroundColor: Colors.red,
//       ),
//     );

//     // Navigate to login
//     Future.microtask(() {
//       context.go('/login');
//     });
//   }

//   void _showProfileSheet() {
//     showModalBottomSheet(
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
//       ),
//       builder: (_) {
//         return Padding(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Profile',
//                 style: TextStyle(
//                   fontSize: 22,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 20),

//               _profileRow('Full Name', fullName),
//               _profileRow('Username', userName),
//               _profileRow('Organization', orgName),
//               _profileRow('Office', officeName),
//               _profileRow('Email', email),
//               _profileRow('Mobile', mobileNo),

//               const SizedBox(height: 28),
//               const Divider(),

//               SizedBox(
//                 width: double.infinity,
//                 height: 48,
//                 child: OutlinedButton.icon(
//                   onPressed: _logout,
//                   icon: const Icon(Icons.logout, color: Colors.red),
//                   label: const Text(
//                     'Logout',
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.red,
//                     ),
//                   ),
//                   style: OutlinedButton.styleFrom(
//                     side: const BorderSide(color: Colors.red),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _profileRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 120,
//             child: Text(
//               label,
//               style: const TextStyle(
//                 fontSize: 15,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//           ),
//           Expanded(
//             child: Text(
//               value.isNotEmpty ? value : '-',
//               style: const TextStyle(
//                 fontSize: 15,
//                 color: Colors.black87,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (userName.isEmpty) return const SizedBox.shrink();

//     return Row(
//       children: [
//         Text(
//           userName,
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         IconButton(
//           icon: const Icon(
//             Icons.account_circle,
//             size: 32,
//             color: AppColors.primary,
//           ),
//           onPressed: _showProfileSheet,
//         ),
//       ],
//     );
//   }
// }
