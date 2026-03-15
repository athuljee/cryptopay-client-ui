import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/blockchain_service.dart';
import '../services/hotspot_listener_service_io.dart' if (dart.library.html) '../services/hotspot_listener_service_stub.dart';
import '../services/network_availability_service.dart';
import '../services/offline_server_service.dart';
import 'send_crypto_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;
  bool isDark = true; // local theme toggle
  bool _hotspotListenerReady = false;
  bool _merchantConnected = false;
  bool _hasInternet = false;
  List<ConnectivityResult> _connectivity = [ConnectivityResult.none];

  final List<Map<String, dynamic>> cryptos = [
    {
      "name": "Bitcoin",
      "symbol": "BTC",
      "amount": 0.0,
      "icon": "assets/icons/btc.png",
      "color": Colors.orange,
    },
    {
      "name": "Ethereum",
      "symbol": "ETH",
      "amount": 0.0,
      "icon": "assets/icons/eth.png",
      "color": Colors.deepPurple,
    },
    {
      "name": "Tether",
      "symbol": "USDT",
      "amount": 0.0,
      "icon": "assets/icons/usdt.png",
      "color": Colors.green,
    },
  ];

  @override
  void initState() {
    super.initState();
    loadBalances();
    _startHotspotListener();
    _checkInternet();
    HotspotListenerService.onMerchantConnected = () {
      if (mounted) setState(() => _merchantConnected = true);
    };
    Connectivity().checkConnectivity().then((r) {
      if (mounted) setState(() => _connectivity = r);
    });
    Connectivity().onConnectivityChanged.listen((r) {
      if (mounted) setState(() => _connectivity = r);
      _checkInternet();
    });
  }

  Future<void> _checkInternet() async {
    final ok = await NetworkAvailabilityService.hasInternet();
    if (mounted && _hasInternet != ok) setState(() => _hasInternet = ok);
  }

  Future<void> _startHotspotListener() async {
    if (!await HotspotListenerService.start()) return;
    if (mounted) setState(() => _hotspotListenerReady = true);
  }

  @override
  void dispose() {
    HotspotListenerService.onMerchantConnected = null;
    super.dispose();
  }

  Future<void> _openHotspotSettings() async {
    final uri = Uri.parse('content://settings/wifi');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Open Settings → Network → Hotspot to turn on mobile hotspot.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loadBalances();
  }

  Future<void> loadBalances() async {
    final balances = await BlockchainService.getBalance();

    setState(() {
      for (var c in cryptos) {
        c["amount"] =
            (balances[c["symbol"]] ?? 0.0).toDouble();
      }
    });
  }

  double get totalBalance {
    const prices = {
      "BTC": 52000.0,
      "ETH": 3400.0,
      "USDT": 1.0,
    };

    double total = 0;
    for (var c in cryptos) {
      total += c["amount"] * prices[c["symbol"]]!;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Main Wallet"),
          actions: [

            /// Theme toggle
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () {
                setState(() => isDark = !isDark);
              },
            ),

            /// Logout button
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {

                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();

                if (!mounted) return;

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  "/login",
                      (_) => false,
                );

              },
            ),

          ],
        ),

        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              /// BALANCE CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Total Balance",
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "\$${totalBalance.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// ACTION BUTTONS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [

                  ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text("Send"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SendCryptoScreen(),
                        ),
                      );

                      loadBalances();
                    },
                  ),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text("Scan"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5CFFB0),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/scan');
                      loadBalances();
                    },
                  ),

                ],
              ),

              const SizedBox(height: 16),

              /// Load to offline wallet (when online)
              if (_hasInternet) ...[
                Card(
                  color: isDark ? Colors.grey[850] : Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: Colors.green[700], size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Load crypto for offline use',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? null : Colors.green[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Transfer from your online wallet to your local offline wallet. Use this balance when paying at merchants without internet.',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.green[800]),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SendCryptoScreen(initialMode: ClientSendMode.local),
                                ),
                              );
                              loadBalances();
                            },
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Load to offline wallet'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              /// OFFLINE / HOTSPOT CARD
              Card(
                color: isDark ? Colors.grey[850] : Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _merchantConnected ? Icons.wifi_tethering : Icons.wifi_tethering_rounded,
                            color: _merchantConnected ? Colors.green : Colors.orange,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Offline payments (hotspot)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? null : Colors.blue[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _merchantConnected
                            ? 'Merchant connected to hotspot. Ready for offline transactions.'
                            : 'Turn on your mobile hotspot. Ask merchant to connect to it, then scan their QR.',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.blue[800]),
                      ),
                      if (_merchantConnected)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                              const SizedBox(width: 4),
                              Text('Ready for offline transactions', style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _openHotspotSettings,
                        icon: const Icon(Icons.settings, size: 18),
                        label: const Text('Open hotspot settings'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              /// ASSETS TITLE
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Your Assets",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 10),


              const SizedBox(height: 20),

              Expanded(
                child: ListView.builder(
                  itemCount: cryptos.length,
                  itemBuilder: (context, index) {
                    final c = cryptos[index];

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: c["color"],
                          child: Image.asset(c["icon"], width: 22),
                        ),
                        title: Text(c["name"]),
                        subtitle: Text(c["symbol"]),
                        trailing: Text(
                          c["amount"].toStringAsFixed(
                            c["symbol"] == "USDT" ? 2 : 6,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          selectedItemColor: const Color(0xFF5CFFB0),
          unselectedItemColor: Colors.grey,
          onTap: (index) {
            setState(() => currentIndex = index);
            if (index == 1) Navigator.pushNamed(context, '/trending');
            if (index == 2) Navigator.pushNamed(context, '/history');
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: "Trending"),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          ],
        ),
      ),
    );
  }
}
