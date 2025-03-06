import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class BackgroundService {
  PorcupineManager? _porcupineManager;
  bool isListening = false;

  Future<void> startListening() async {
    try {
      _porcupineManager = await PorcupineManager.fromKeywordPaths(
        "OAztUxzOjVGR9smI5zur1P3QqZFvNluY1hgEMh2/OMrMdKhvWnLfVA==", // Replace with your actual key
        [
          "assets/hey-todo_en_android_v3_0_0.ppn"
        ], // Path to your wake word model
        _wakeWordCallback,
        sensitivities: [0.7],
      );

      await _porcupineManager?.start();
      isListening = true;
    } on PorcupineException catch (err) {
      print("Error: ${err.message}");
    }
  }

  void _wakeWordCallback(int keywordIndex) {
    if (keywordIndex == 0) {
      FlutterForegroundTask.launchApp(); // Bring app to foreground
    }
  }

  Future<void> stopListening() async {
    await _porcupineManager?.stop();
    isListening = false;
  }
}
