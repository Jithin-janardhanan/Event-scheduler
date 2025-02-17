// import 'package:flutter/material.dart';
// import 'package:lucide_icons/lucide_icons.dart';
// import 'package:new_todo/view/TextSheduler.dart';

// class HomePage extends StatefulWidget {
//   @override
//   _HomePageState createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   final TextEditingController titleController = TextEditingController();
//   DateTime? selectedDateTime;
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Shedulers'),
//         automaticallyImplyLeading: false,
//         centerTitle: true,
//         actions: [],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             Expanded(
//               child: GridView.count(
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 12,
//                 mainAxisSpacing: 12,
//                 children: [
//                   _buildClickableCard(
//                     context,
//                     LucideIcons.plus,
//                     "Text Reminder",
//                     () => Navigator.push(
//                       context,
//                       MaterialPageRoute(builder: (context) => SheduleTask()),
//                     ),
//                   ),
//                   _buildClickableCard(
//                     context,
//                     LucideIcons.fileAudio,
//                     "Voice to Text",
//                     () => Navigator.push(
//                       context,
//                       MaterialPageRoute(builder: (context) => SheduleTask()),
//                     ),
//                   ),
//                   _buildClickableCard(
//                     context,
//                     LucideIcons.languages,
//                     "Local lang to Eng",
//                     () => Navigator.push(
//                       context,
//                       MaterialPageRoute(builder: (context) => SheduleTask()),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildClickableCard(
//     BuildContext context,
//     IconData iconData,
//     String title,
//     VoidCallback onTap,
//   ) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Card(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         elevation: 4,
//         child: Center(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(iconData, size: 40, color: Colors.deepPurple),
//               const SizedBox(height: 8),
//               Text(
//                 title,
//                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
