import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:new_todo/model/Authentication_service.dart';
import 'package:new_todo/model/notification_sevice.dart';
import 'package:new_todo/model/Biometric.dart';
import 'package:new_todo/view/SplashScreen.dart';
import 'package:new_todo/view/loginPage.dart';
import 'package:new_todo/view/userhomepage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initNotification();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final AuthService authService = AuthService();
  MyApp({super.key});

  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
  
      home: SplashScreen(),
    );
  }
}
