import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:new_todo/controller/background_service.dart';
import 'package:new_todo/model/notification_sevice.dart';
import 'package:new_todo/view/dummyhomepage.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:translator/translator.dart';

class SheduleTask extends StatefulWidget {
  const SheduleTask({super.key});

  @override
  _SheduleTaskState createState() => _SheduleTaskState();
}

class _SheduleTaskState extends State<SheduleTask> {
  DateTime? selectedDateTime;
  String selectedLanguage = 'en-US';
  bool _isProcessingCommand = false;

  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final stt.SpeechToText _speech = stt.SpeechToText();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  String? _uploadedImageUrl;
  final BackgroundService _backgroundService = BackgroundService();
  String _statusText = 'Press Start to listen for wake word';

  GoogleTranslator translator = GoogleTranslator();

  TextEditingController taskTitleController = TextEditingController();
  TextEditingController recognizedTextController =
      TextEditingController(text: "Tap the mic and speak");

  bool isListening = false;
  String listeningLocale = "ml_IN"; // Default to Malayalam
  bool translateToEnglish = true;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _notificationService.initNotification();
    _initializeSpeech();
  }

  @override
  void dispose() {
    taskTitleController.dispose();
    recognizedTextController.dispose();
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (error) => print('Speech error: $error'),
    );
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition not available'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleListening() async {
    if (!isListening) {
      // Stop the wakeup feature if it is active
      if (_backgroundService.isListening) {
        await _backgroundService.stopListening();
        setState(() {
          _statusText = 'Stopped listening for wake word';
        });
      }

      bool available = await _speech.initialize();
      if (available) {
        setState(() => isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              recognizedTextController.text = result.recognizedWords;
            });
            if (result.finalResult) {
              setState(() {
                isListening = false;
                _isProcessingCommand = true;
              });
              _processRecognizedText(result.recognizedWords);
              setState(() => _isProcessingCommand = false);
            }
          },
          localeId: listeningLocale,
        );
      }
    } else {
      setState(() => isListening = false);
      _speech.stop();

      // Restart the wakeup feature if it was previously active
      if (!_backgroundService.isListening) {
        await _backgroundService.startListening();
        setState(() {
          _statusText = 'Listening for wake word "Hey ToDo"...';
        });
      }
    }
  }

  void _processRecognizedText(String text) {
    if (text.isEmpty) return;

    // If translate toggle is on and we're listening in Malayalam, translate
    if (translateToEnglish && listeningLocale == "ml_IN") {
      _translateAndProcess(text, from: 'ml', to: 'en');
    } else {
      // If translate is off or we're listening to English, process directly
      setState(() {
        taskTitleController.text = text;
      });
      _processVoiceCommand(text);
    }
  }

  void _translateAndProcess(String text,
      {required String from, required String to}) {
    translator.translate(text, from: from, to: to).then((translation) {
      setState(() {
        taskTitleController.text = translation.text;
      });
      _processVoiceCommand(translation.text);
    }).catchError((error) {
      setState(() {
        taskTitleController.text = "Translation error: $error";
      });
    });
  }

  void _processVoiceCommand(String text) {
    setState(() {
      _isProcessingCommand = true;
    });

    text = text.toLowerCase();
    _extractDateTimeFromVoice(text);

    setState(() {
      _isProcessingCommand = false;
    });
  }

  void _extractDateTimeFromVoice(String text) {
    DateTime now = DateTime.now();
    DateTime? dateTime;

    // Clean up the text - remove periods from a.m./p.m. format
    String cleanedText = text
        .replaceAll(RegExp(r'a\.m\.', caseSensitive: false), 'am')
        .replaceAll(RegExp(r'p\.m\.', caseSensitive: false), 'pm');

    // Extract AM/PM from text first
    String period = '';
    RegExp periodRegex = RegExp(r'\b(am|pm)\b', caseSensitive: false);
    Match? periodMatch = periodRegex.firstMatch(cleanedText.toLowerCase());
    if (periodMatch != null && periodMatch.group(1) != null) {
      period = periodMatch.group(1)!.toLowerCase();
    }

    // Normalize the text to lowercase for consistent matching
    String lowerText = cleanedText.toLowerCase();

    // Check for relative date references
    if (lowerText.contains('today') || lowerText.contains('ഇന്ന്')) {
      dateTime = DateTime(now.year, now.month, now.day);
    } else if (lowerText.contains('day after tomorrow') ||
        lowerText.contains('മറ്റന്നാൾ')) {
      dateTime = DateTime(now.year, now.month, now.day + 2);
    } else if (lowerText.contains('next week') ||
        lowerText.contains('അടുത്ത ആഴ്ച')) {
      dateTime = DateTime(now.year, now.month, now.day + 7);
    } else if (lowerText.contains('tomorrow') || lowerText.contains('നാളെ')) {
      dateTime = DateTime(now.year, now.month, now.day + 1);
    } else {
      // Default to today if no date mentioned
      dateTime = DateTime(now.year, now.month, now.day);
    }

    // Default time (9 AM)
    int hour = 9;
    int minute = 0;

    // Look for specific time patterns
    final List<RegExp> timePatterns = [
      RegExp(r'\b(\d{1,2}):(\d{2})(?:\s*(am|pm))?\b', caseSensitive: false),
      RegExp(r'\b(\d{1,2})\s*(am|pm)\b', caseSensitive: false),
      RegExp(r"\b(\d{1,2})\s*o'?clock\b", caseSensitive: false),
      RegExp(r'\b(\d{1,2})\.(\d{2})(?:\s*(am|pm))?\b',
          caseSensitive: false), // For times like 3.00pm
    ];

    for (RegExp pattern in timePatterns) {
      Match? match = pattern.firstMatch(cleanedText);
      if (match != null) {
        hour = int.parse(match.group(1)!);

        // Handle minutes if available
        if (match.groupCount >= 2 &&
            match.group(2) != null &&
            !match.group(2)!.toLowerCase().contains('am') &&
            !match.group(2)!.toLowerCase().contains('pm')) {
          minute = int.parse(match.group(2)!);
        }

        // Handle period (am/pm) from match if available
        String? matchPeriod =
            match.groupCount >= 3 ? match.group(3)?.toLowerCase() : null;
        if (matchPeriod == null && match.groupCount >= 2) {
          if (match.group(2)?.toLowerCase() == 'am' ||
              match.group(2)?.toLowerCase() == 'pm') {
            matchPeriod = match.group(2)?.toLowerCase();
          }
        }

        // Use period from match if available, otherwise use the one found earlier
        if (matchPeriod != null) {
          period = matchPeriod;
        }

        break;
      }
    }

    // Process time references if no specific time found
    if (period.isEmpty) {
      if (lowerText.contains('morning') || lowerText.contains('രാവിലെ')) {
        hour = 9;
        period = 'am';
      } else if (lowerText.contains('afternoon') ||
          lowerText.contains('ഉച്ചതിരിഞ്ഞ്') ||
          lowerText.contains('ഉച്ചാ')) {
        hour = 2;
        period = 'pm';
      } else if (lowerText.contains('evening') ||
          lowerText.contains('വൈകുന്നേരം')) {
        hour = 6;
        period = 'pm';
      } else if (lowerText.contains('night') || lowerText.contains('രാത്രി')) {
        hour = 8;
        period = 'pm';
      }
    }

    // Convert hour based on AM/PM
    if (period == 'pm' && hour < 12) {
      hour += 12;
    } else if (period == 'am' && hour == 12) {
      hour = 0;
    }

    // Update dateTime with the hour and minute
    dateTime =
        DateTime(dateTime.year, dateTime.month, dateTime.day, hour, minute);

    // Only adjust if both are on the same day
    bool isSameDay = dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;

    // Only adjust past times when specifically scheduling for today
    if (lowerText.contains('today') && isSameDay && dateTime.isBefore(now)) {
      // Do not adjust - keep it on today even if time has passed
    } else if (dateTime.isBefore(now) && isSameDay) {
      // If it's today and the time has already passed but "today" wasn't specified,
      // then assume tomorrow
      dateTime = dateTime.add(const Duration(days: 1));
    }

    setState(() {
      selectedDateTime = dateTime;
    });
  }

  void _toggleLanguage() {
    setState(() {
      if (listeningLocale == "ml_IN") {
        listeningLocale = "en-US";
      } else {
        listeningLocale = "ml_IN";
      }
    });
  }

  Future<void> _pickDateTime() async {
    DateTime now = DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          selectedDateTime = DateTime(pickedDate.year, pickedDate.month,
              pickedDate.day, pickedTime.hour, pickedTime.minute);
        });
      }
    }
  }

  Future<void> _scheduleTask() async {
    if (selectedDateTime == null || taskTitleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date, time, and enter a title.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image before scheduling the task'),
        ),
      );
      return;
    }

    try {
      // First upload image to Cloudinary
      String? uploadedUrl = await uploadToCloudinary(_selectedImage!);
      if (uploadedUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload image')),
        );
        return;
      }

      // Schedule notification
      int notificationId =
          DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await _notificationService.scheduleNotification(
        id: notificationId,
        scheduledTime: selectedDateTime!,
        title: taskTitleController.text,
      );

      // Save to Firebase Firestore with image URL
      final user = _auth.currentUser;
      if (user != null) {
        // Create the task document in Firestore
        await _firestore.collection('notifications').add({
          'userId': user.uid,
          'title': taskTitleController.text,
          'scheduledTime': selectedDateTime!.toIso8601String(),
          'notificationId': notificationId,
          'imageUrl': uploadedUrl, // Add the Cloudinary image URL
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'active'
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task and image saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => Dummyhomepage(),
            ));

        // Clear the form
        setState(() {
          selectedDateTime = null;
          taskTitleController.clear();
          recognizedTextController.clear();
          _selectedImage = null;
          _uploadedImageUrl = uploadedUrl;
        });
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving task: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          "Schedule Task",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main task input card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title section
                      Text(
                        "Task Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Task title with speech recognition
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: taskTitleController,
                              decoration: InputDecoration(
                                labelText: 'Task Title',
                                labelStyle:
                                    TextStyle(color: Colors.blue.shade600),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                prefixIcon: Icon(Icons.task_alt,
                                    color: Colors.blue.shade600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: isListening
                                  ? Colors.red.shade50
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: IconButton(
                              icon: Icon(
                                isListening ? Icons.mic : Icons.mic_none,
                                color: isListening
                                    ? Colors.red
                                    : Colors.blue.shade600,
                              ),
                              onPressed: _toggleListening,
                              tooltip: "Speak to add task",
                            ),
                          ),
                        ],
                      ),

                      // Recognized text display (only show when there's text)
                      if (recognizedTextController.text.isNotEmpty &&
                          recognizedTextController.text !=
                              "Tap the mic and speak")
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Recognized Speech:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  recognizedTextController.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Time and Date Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Date & Time",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 21, 101, 192),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selected date-time display
                      if (selectedDateTime != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.event_available,
                                  color: Colors.blue.shade700),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('EEEE, MMMM d, yyyy')
                                        .format(selectedDateTime!),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "at ${DateFormat('h:mm a').format(selectedDateTime!)}",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.event_busy,
                                  color: Colors.grey.shade600),
                              const SizedBox(width: 12),
                              Text(
                                "No date and time selected",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Date picker button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _pickDateTime,
                          icon: const Icon(Icons.calendar_month),
                          label: const Text('Select Date & Time'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Image and Settings Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Attachment & Settings",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Image picker
                      Row(
                        children: [
                          // Show selected image preview or placeholder
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                              image: _selectedImage != null
                                  ? DecorationImage(
                                      image: FileImage(_selectedImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _selectedImage == null
                                ? Icon(Icons.image,
                                    color: Colors.grey.shade400, size: 32)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Add Image",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedImage != null
                                      ? "Image selected"
                                      : "No image selected",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontStyle: _selectedImage != null
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.add_photo_alternate),
                            label: const Text('Browse'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade100,
                              foregroundColor: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Translation switch
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.translate,
                                  color: Colors.blue.shade600),
                              const SizedBox(width: 12),
                              Text(
                                "Translate To English",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: translateToEnglish,
                            onChanged: (value) {
                              setState(() {
                                translateToEnglish = value;
                              });
                            },
                            activeColor: Colors.blue.shade600,
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Language toggle
                      // Row(
                      //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //   children: [
                      //     Row(
                      //       children: [
                      //         // Icon(Icons.language, color: Colors.blue.shade600),
                      //         // const SizedBox(width: 12),
                      //         //   Text(
                      //         //     "Speech Language",
                      //         //     style: TextStyle(
                      //         //       fontSize: 15,
                      //         //       fontWeight: FontWeight.w500,
                      //         //     ),
                      //         //   ),
                      //       ],
                      //     ),
                      //     // TextButton.icon(
                      //     //   onPressed: _toggleLanguage,
                      //     //   icon: Icon(
                      //     //     listeningLocale == "ml_IN"
                      //     //         ? Icons.record_voice_over
                      //     //         : Icons.voice_over_off,
                      //     //     color: Colors.blue.shade600,
                      //     //   ),
                      //     //   label: Text(
                      //     //     "Malayalam", // Always displays "Malayalam"
                      //     //     style: TextStyle(color: Colors.blue.shade800),
                      //     //   ),
                      //     // ),
                      //   ],
                      // ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  // Clear button
                  Expanded(
                    flex: 1,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          taskTitleController.clear();
                          recognizedTextController.text =
                              "Tap the mic and speak";
                          selectedDateTime = null;
                          _selectedImage = null;
                        });
                      },
                      icon: const Icon(Icons.clear_all),
                      label: const Text("Clear All"),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.red.shade600,
                        backgroundColor: Colors.red.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Schedule task button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _scheduleTask,
                      icon: const Icon(Icons.schedule_send),
                      label: const Text('Schedule Task'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
    );
  }
}

// upload image
final http.Client _client = http.Client();

Future<String?> uploadToCloudinary(File imagePath) async {
  try {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/dxkqhwllg/upload');

    var request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = 'Event management'
      ..files.add(await http.MultipartFile.fromPath('file', imagePath.path));

    var streamedResponse = await _client.send(request);
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(response.body);
      return jsonMap['secure_url'] as String;
    } else {
      throw Exception('Upload failed: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error uploading image: $e');
  }
}
