// import 'package:barcode_generator/common_widgets/profile_action_widget.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import '../providers/qr_provider.dart';

// class QrPage extends StatefulWidget {
//   const QrPage({super.key});

//   @override
//   State<QrPage> createState() => _QrPageState();
// }

// class _QrPageState extends State<QrPage> {
//   @override
//   void initState() {
//     super.initState();
//     // 🔥 Restore QR or expire it
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<QrProvider>().loadExistingQr();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final provider = context.watch<QrProvider>();

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('QR Generator'),
//         actions: const [
//           ProfileActionWidget(),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             SizedBox(
//               width: double.infinity,
//               height: 48,
//               child: ElevatedButton(
//                 onPressed: provider.status == QrStatus.loading
//                     ? null
//                     : () {
//                         context.read<QrProvider>().generateQr();
//                       },
//                 style: ElevatedButton.styleFrom(
//                   side: const BorderSide(width: 1),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//                 child: provider.status == QrStatus.loading
//                     ? const CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: Colors.white,
//                       )
//                     : const Text(
//                         'Generate QR',
//                         style: TextStyle(fontSize: 16),
//                       ),
//               ),
//             ),

//             const SizedBox(height: 30),

//             if (provider.status == QrStatus.success &&
//                 provider.qrImageUrl != null)
//               Column(
//                 children: [
//                   const Text(
//                     'Your QR Code (Valid for 24 hours)',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Image.network(
//                     provider.qrImageUrl!,
//                     height: 220,
//                     errorBuilder: (_, __, ___) =>
//                         const Text('Failed to load image'),
//                   ),
//                 ],
//               ),

//             if (provider.status == QrStatus.error)
//               Text(
//                 provider.error ?? 'Something went wrong',
//                 style: const TextStyle(color: Colors.red),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
