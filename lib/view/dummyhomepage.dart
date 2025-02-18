import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_todo/model/notification_sevice.dart';
import 'package:new_todo/view/TextSheduler.dart';
import 'package:new_todo/view/loginPage.dart';

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

  @override
  Widget build(BuildContext context) {
    const Color sandColor = Color.fromARGB(255, 237, 237, 205);
    const Color button = Color.fromARGB(255, 0, 0, 0);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80.0,
        backgroundColor: sandColor,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: Icon(Icons.person, size: 30, color: button),
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
              style: const TextStyle(fontSize: 17),
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
              icon: const Icon(Icons.logout, color: button),
            ),
          ),
        ],
      ),
      backgroundColor: sandColor,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search, color: button),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 11.0),
                ),
                onChanged: (value) {
                  setState(() {});
                },
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
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey)),
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
                      final bool isPast =
                          scheduledTime.isBefore(DateTime.now());

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {},
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    // Status indicator
                                    Container(
                                      width: 3,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isPast
                                            ? Colors.red.withOpacity(0.7)
                                            : Colors.green.withOpacity(0.7),
                                        borderRadius:
                                            BorderRadius.circular(1.5),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Content
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['title'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              decoration: isPast
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              color: isPast
                                                  ? Colors.grey
                                                  : Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: isPast
                                                    ? Colors.grey
                                                    : Colors.black54,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                DateFormat('MMM dd, HH:mm')
                                                    .format(scheduledTime),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isPast
                                                      ? Colors.grey
                                                      : Colors.black54,
                                                ),
                                              ),
                                              if (isPast) ...[
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.warning_rounded,
                                                  size: 12,
                                                  color: Colors.red
                                                      .withOpacity(0.8),
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  'Past due',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.red
                                                        .withOpacity(0.8),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Delete button
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(50),
                                        onTap: () => deleteTask(
                                            doc.id, data['notificationId']),
                                        child: Padding(
                                          padding: const EdgeInsets.all(6.0),
                                          child: Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.red.withOpacity(0.7),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Future<void> deleteTask(String docId, int notificationId) async {
    try {
      await _firestore.collection('notifications').doc(docId).delete();
      await _notificationService.cancelNotification(notificationId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Task deleted successfully'),
          backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete task: $e'),
          backgroundColor: Colors.red));
    }
  }
}
