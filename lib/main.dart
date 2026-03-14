import 'package:flutter/material.dart';

// Screens
import 'screens/auth_gate.dart';
import 'screens/home_screen.dart';
import 'screens/trending_page.dart';
import 'screens/qr_scan_page.dart';
import 'screens/transaction_history.dart';
import 'screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';


// Services


Future<void> main() async {
  /// REQUIRED for async + SharedPreferences
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final user = prefs.getString("user");

  /// Initialize demo balances ONCE
  //await LocalStorage.initDemoBalance();

  runApp(ClientPayApp(startLoggedIn: user != null));
}

class ClientPayApp extends StatelessWidget {
  final bool startLoggedIn;

  const ClientPayApp({super.key, required this.startLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "CryptoPay Client Wallet",
      debugShowCheckedModeBanner: false,



      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),

      /// First screen → biometric gate
      home: const AuthGate(),

      /// Named routes
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/trending': (_) => const TrendingPage(),
        '/scan': (_) => const QRScanPage(),
        '/history': (_) => const TransactionHistory(),
      },
    );
  }
}
