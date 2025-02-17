import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../model/notification_sevice.dart';
import 'dummyhomepage.dart';

class SheduleTask extends StatefulWidget {
  const SheduleTask({super.key});

  @override
  _SheduleTaskState createState() => _SheduleTaskState();
}

class _SheduleTaskState extends State<SheduleTask> {
  final TextEditingController titleController = TextEditingController();
  DateTime? selectedDateTime;
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isProcessingCommand = false;

  @override
  void initState() {
    super.initState();
    _notificationService.initNotification();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (errorNotification) => print('Speech error: $errorNotification'),
    );
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition not available on this device'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _processVoiceCommand(String text) {
    setState(() {
      _isProcessingCommand = true;
    });

    // Convert to lowercase for easier matching
    text = text.toLowerCase();

    // Extract date and time first
    _extractDateTimeFromVoice(text);

    // Clean up the remaining text for title
    String title = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Set the title if it's not empty
    if (title.isNotEmpty) {
      setState(() {
        titleController.text = title;
      });
    }

    setState(() {
      _isProcessingCommand = false;
    });
  }

  void _extractDateTimeFromVoice(String text) {
    DateTime now = DateTime.now();
    DateTime? dateTime;

    // Check for relative date references
    if (text.contains('today')) {
      dateTime = DateTime(now.year, now.month, now.day - 1);
    } else if (text.contains('day after tomorrow')) {
      dateTime = DateTime(now.year, now.month, now.day + 2);
    } else if (text.contains('next week')) {
      dateTime = DateTime(now.year, now.month, now.day + 7);
    } else if (text.contains('tomorrow')) {
      dateTime = DateTime(now.year, now.month, now.day + 1);
    } else {
      dateTime = DateTime(now.year, now.month, now.day - 1);
    }

    // Check for time of day references
    if (text.contains('morning') || text.contains('am')) {
      dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day, 9, 0);
    } else if (text.contains('afternoon') || text.contains('p.m.')) {
      dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day, 14, 0);
    } else if (text.contains('evening') || text.contains('pm')) {
      dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day, 18, 0);
    } else if (text.contains('night') || text.contains('pm')) {
      dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day, 20, 0);
    }

    // Look for specific time patterns
    final List<RegExp> timePatterns = [
      RegExp(r'\b(\d{1,2}):(\d{2})(?:\s*(am|pm))?\b', caseSensitive: false),
      RegExp(r'\b(\d{1,2})\s*(am|pm)\b', caseSensitive: false),
      RegExp(r"\b(\d{1,2})\s*o'?clock\b", caseSensitive: false),
    ];

    for (RegExp pattern in timePatterns) {
      Match? match = pattern.firstMatch(text);
      if (match != null) {
        int hour = int.parse(match.group(1)!);
        int minute = 0;

        if (match.groupCount >= 2 && match.group(2) != null) {
          minute = int.parse(match.group(2)!);
        }

        String? period =
            match.groupCount >= 3 ? match.group(3)?.toLowerCase() : null;
        if (period == 'pm' && hour < 12) {
          hour += 12;
        } else if (period == 'am' && hour == 12) {
          hour = 0;
        }

        dateTime = DateTime(
          dateTime!.year,
          dateTime.month,
          dateTime.day,
          hour,
          minute,
        );
        break;
      }
    }

    if (dateTime!.isBefore(now)) {
      dateTime = dateTime.add(const Duration(days: 1));
    }

    setState(() {
      selectedDateTime = dateTime;
    });
  }

  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            if (result.finalResult) {
              setState(() {
                _isListening = false;
                _isProcessingCommand = true;
              });
              _processVoiceCommand(result.recognizedWords);
              setState(() => _isProcessingCommand = false);
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _selectDateTime() async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (selectedDate != null) {
      TimeOfDay? selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (selectedTime != null) {
        setState(() {
          selectedDateTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _scheduleTask() async {
    if (selectedDateTime == null || titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date, time, and enter a title.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _notificationService.scheduleNotification(
      id: notificationId,
      scheduledTime: selectedDateTime!,
      title: titleController.text,
    );

    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('notifications').add({
        'userId': user.uid,
        'title': titleController.text,
        'scheduledTime': selectedDateTime!.toIso8601String(),
        'notificationId': notificationId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task scheduled successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    setState(() {
      selectedDateTime = null;
      titleController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color sandColor = Color.fromARGB(255, 237, 237, 205);
    const Color button = Colors.black;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80.0,
        backgroundColor: sandColor,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: Icon(Icons.person, size: 30, color: button),
        ),
      ),
      backgroundColor: sandColor,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.chat_bubble_outline, color: button),
                          SizedBox(width: 8),
                          Text(
                            "Schedule New Task",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: button,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: button),
                            const SizedBox(width: 4),
                            Text(
                              selectedDateTime == null
                                  ? 'No Date Selected'
                                  : DateFormat('yyyy-MM-dd HH:mm')
                                      .format(selectedDateTime!),
                              style: const TextStyle(color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: titleController,
                                    decoration: const InputDecoration(
                                      hintText: 'Type your task here...',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.all(16),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _toggleListening,
                                  icon: Icon(
                                    _isListening ? Icons.mic : Icons.mic_none,
                                    color:
                                        _isListening ? Colors.red : Colors.grey,
                                  ),
                                  tooltip: 'Speak task title',
                                ),
                              ],
                            ),
                            if (_isProcessingCommand)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _selectDateTime,
                              icon: const Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: Colors.black,
                              ),
                              label: const Text(
                                'Pick Date',
                                style: TextStyle(color: Colors.black),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.brown[100],
                                foregroundColor: button,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await _scheduleTask();
                                if (mounted) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const Dummyhomepage(),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.send,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Schedule',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: button,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
