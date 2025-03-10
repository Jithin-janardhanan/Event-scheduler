import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:new_todo/view/TextSheduler.dart';
import 'package:new_todo/view/dummyhomepage.dart';
import 'package:new_todo/view/loginPage.dart';


class Biometric extends StatefulWidget {
  const Biometric({super.key});

  @override
  State<Biometric> createState() => _BiometricState();
}

class _BiometricState extends State<Biometric> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _authenticateWithBiometrics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            if (isAuthenticated) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => Dummyhomepage()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => Loginpage()),
              );
            }
          },
          child: Text(
           'Go to Signup Page',
          ),
        ),
      ),
    );
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (canCheckBiometrics) {
        bool authenticated = await _localAuth.authenticate(
          localizedReason: 'Use your fingerprint to unlock the app',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: false,
          ),
        );

        if (authenticated) {
          setState(() {
            isAuthenticated = true;
          });

          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => Dummyhomepage()),
            );
          }
        } else {
          // Show failure message and stay on the same screen
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometric authentication failed.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      print("Biometric authentication error: $e");
    }
  }
}
