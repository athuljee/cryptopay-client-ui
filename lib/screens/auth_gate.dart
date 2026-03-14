import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import '../services/blockchain_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    try {
      _isAuthenticating = true;

      final bool isSupported = await _auth.isDeviceSupported();
      final bool canCheck = await _auth.canCheckBiometrics;

      if (!isSupported || !canCheck) {
        _goHome();
        return;
      }

      final bool success = await _auth.authenticate(
        localizedReason: "Unlock your CryptoPay Wallet",
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (success && mounted) {
        _goHome();
      }
    } catch (e) {
      debugPrint("Biometric error: $e");
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> _goHome() async {

    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString("user");

    if (!mounted) return;

    if (savedUser != null) {

      // restore wallet
      BlockchainService.clientAddress = savedUser;

      Navigator.pushReplacementNamed(context, "/home");

    } else {

      Navigator.pushReplacementNamed(context, "/login");

    }

  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fingerprint, size: 96, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              "Authenticate to continue",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _authenticate,
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }
}
