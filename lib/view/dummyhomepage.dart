import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intl/intl.dart';

import 'package:new_todo/model/notification_sevice.dart';
import 'package:new_todo/view/TextSheduler.dart';
import 'package:new_todo/view/loginPage.dart';
import 'package:permission_handler/permission_handler.dart';

import '../controller/background_service.dart';

class Dummyhomepage extends StatefulWidget {
  const Dummyhomepage({super.key});

  @override
  State<Dummyhomepage> createState() => _DummyhomepageState();
}

class _DummyhomepageState extends State<Dummyhomepage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _searchController = TextEditingController();
  final BackgroundService _backgroundService = BackgroundService();
  bool _isListening = false;

  String _statusText = 'Press Start to listen for wake word';
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (await Permission.microphone.request().isGranted) {
      setState(() {
        _statusText = 'Microphone permission granted. Ready to initialize.';
      });
    } else {
      setState(() {
        _statusText = 'Microphone permission denied';
      });
    }
  }

  Future<void> _startListening() async {
    await FlutterForegroundTask.startService(
      notificationTitle: "Listening for 'Hey ToDo'",
      notificationText: "Wake word detection is active",
    );

    await _backgroundService.startListening();
    setState(() {
      _isListening = true;
      _statusText = 'Listening for wake word "Hey ToDo"...';
    });
  }

  Future<void> _stopListening() async {
    await FlutterForegroundTask.stopService();
    await _backgroundService.stopListening();
    setState(() {
      _isListening = false;
      _statusText = 'Stopped listening';
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color sandColor = Colors.white;
    const Color button = Color.fromARGB(255, 21, 101, 192);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80.0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF21CBF3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('Users')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text("Loading...");
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Text("User not found");
            }
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            return Text(
              "Hi, ${userData['username'] ?? 'User'}!",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Confirm Logout'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await _auth.signOut();
                            if (mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const Loginpage()),
                                (route) => false,
                              );
                            }
                          },
                          child: const Text('Logout'),
                        ),
                      ],
                    );
                  },
                );
              },
              icon: const Icon(Icons.logout, color: Colors.white),
            ),
          ),
          ElevatedButton(
            onPressed: _isListening ? _stopListening : _startListening,
            child: Text(_isListening ? 'Stop Listening' : 'Start Listening'),
          )
        ],
      ),
      backgroundColor: sandColor,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(13.0),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search, color: button),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 11.0),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Firestore Notifications List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _auth.currentUser == null
                  ? null
                  : _firestore
                      .collection('notifications')
                      .where('userId', isEqualTo: _auth.currentUser?.uid)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading notifications',
                        style: TextStyle(color: Colors.red)),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No tasks scheduled',
                            style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final searchQuery = _searchController.text.toLowerCase();
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['title']
                      .toString()
                      .toLowerCase()
                      .contains(searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final DateTime scheduledTime =
                        DateTime.parse(data['scheduledTime']);
                    final bool isPast = scheduledTime.isBefore(DateTime.now());

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: isPast
                          ? Colors.white
                          : const Color.fromARGB(
                              255, 101, 151, 175), // Background color change
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Status indicator
                            Container(
                              width: 5,
                              height: 50,
                              decoration: BoxDecoration(
                                color: isPast
                                    ? Colors.red.withOpacity(0.7)
                                    : button,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Image thumbnail (if available)
                            if (data['imageUrl'] != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  data['imageUrl'],
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[200],
                                      child: const Icon(
                                          Icons.image_not_supported,
                                          size: 20),
                                    );
                                  },
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],

                            // Task Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      decoration: isPast
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color:
                                          isPast ? Colors.grey : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time,
                                          size: 14,
                                          color: isPast
                                              ? Colors.grey
                                              : Colors.black54),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat('MMM dd, HH:mm')
                                            .format(scheduledTime),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: isPast
                                                ? Colors.grey
                                                : Colors.black54),
                                      ),
                                      if (isPast) ...[
                                        const SizedBox(width: 8),
                                        Icon(Icons.warning_rounded,
                                            size: 12,
                                            color: Colors.red.withOpacity(0.8)),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Past due',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  Colors.red.withOpacity(0.8)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Delete button
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded,
                                  color: Colors.red.withOpacity(0.7), size: 20),
                              onPressed: () =>
                                  deleteTask(doc.id, data['notificationId']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(8.0),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => SheduleTask()));
          },
          backgroundColor: button,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: const Icon(Icons.add, size: 30, color: Colors.white),
          tooltip: 'Add Task',
          elevation: 5,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Future<void> deleteTask(String docId, int notificationId) async {
    try {
      // Get the document data before deleting
      final docSnapshot =
          await _firestore.collection('notifications').doc(docId).get();
      final data = docSnapshot.data();

      // Delete from Firestore
      await _firestore.collection('notifications').doc(docId).delete();

      // Cancel notification
      await _notificationService.cancelNotification(notificationId);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
