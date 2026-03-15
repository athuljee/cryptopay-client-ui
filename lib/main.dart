import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Screens
import 'screens/auth_gate.dart';
import 'screens/main_shell.dart';
import 'screens/home_screen.dart';
import 'screens/trending_page.dart';
import 'screens/qr_scan_page.dart';
import 'screens/transaction_history.dart';
import 'screens/offline_wallet_screen.dart';
import 'screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/hotspot_listener_service_io.dart' if (dart.library.html) 'services/hotspot_listener_service_stub.dart';

// Services
import 'services/offline_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final user = prefs.getString("user");

  try {
    OfflineSyncService.startListening();
  } catch (e, st) {
    debugPrint("OfflineSyncService.startListening: $e $st");
  }
  try {
    await HotspotListenerService.start();
  } catch (e, st) {
    debugPrint("HotspotListenerService.start: $e $st");
  }

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

      /// Named routes (main app uses MainShell with 4 tabs: Home, Trending, Transactions, Offline Wallet)
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const MainShell(),
        '/trending': (_) => const TrendingPage(),
        '/scan': (_) => const QRScanPage(),
        '/history': (_) => const TransactionHistory(),
        '/offline-wallet': (_) => const OfflineWalletScreen(),
      },
    );
  }
}
