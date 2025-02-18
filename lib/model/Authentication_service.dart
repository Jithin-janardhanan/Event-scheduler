import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final LocalAuthentication auth = LocalAuthentication();

  Future<void> signUp(String email, String password) async {
    await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _setLoginStatus(true);
  }

  Future<void> login(String email, String password) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _setLoginStatus(true);
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
    await _setLoginStatus(false);
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      bool canCheckBiometrics = await auth.canCheckBiometrics;
      if (canCheckBiometrics) {
        bool authenticated = await auth.authenticate(
          localizedReason: 'Use fingerprint to access your To-Do list',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );
        return authenticated;
      }
    } catch (e) {
      print("Biometric authentication error: $e");
    }
    return false;
  }

  Future<void> _setLoginStatus(bool status) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isLoggedIn', status);
  }

  Future<bool> getLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }
}
