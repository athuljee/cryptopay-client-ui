import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/blockchain_service.dart';
import '../services/hotspot_listener_service_io.dart' if (dart.library.html) '../services/hotspot_listener_service_stub.dart';
import '../services/network_availability_service.dart';
import 'load_offline_wallet_screen.dart';
import 'send_crypto_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  /// When true, used inside MainShell: no bottom nav, theme from parent.
  final bool embedded;
  /// When embedded, theme is controlled by shell; this is the current value.
  final bool? isDark;
  /// When embedded, theme toggle notifies the shell.
  final ValueChanged<bool>? onThemeChanged;

  const HomeScreen({
    super.key,
    this.embedded = false,
    this.isDark,
    this.onThemeChanged,
  });

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

  /// Main wallet (online) balances – only valid when online.
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
    try {
      final balances = await BlockchainService.getBalance();
      if (mounted) {
        setState(() {
          for (var c in cryptos) {
            c["amount"] = (balances[c["symbol"]] ?? 0.0).toDouble();
          }
        });
      }
    } catch (_) {
      // Offline or error – main balance stays as is; offline balance from cache
    }
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

  bool get _effectiveIsDark => widget.embedded ? (widget.isDark ?? isDark) : isDark;

  @override
  Widget build(BuildContext context) {
    final effectiveIsDark = _effectiveIsDark;
    final content = Scaffold(
        appBar: AppBar(
          title: const Text("Main Wallet"),
          actions: [

            /// Theme toggle
            IconButton(
              icon: Icon(effectiveIsDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () {
                if (widget.embedded && widget.onThemeChanged != null) {
                  widget.onThemeChanged!(!effectiveIsDark);
                } else {
                  setState(() => isDark = !isDark);
                }
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

        body: RefreshIndicator(
          onRefresh: () async {
            await _checkInternet();
            await loadBalances();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
              /// When online: Main Wallet. When offline: show only Offline balance below.
              if (_hasInternet) ...[
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
                        "Main Wallet (Online)",
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
              ],

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
                  color: _effectiveIsDark ? Colors.grey[850] : Colors.green[50],
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
                                color: _effectiveIsDark ? null : Colors.green[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Internal transfer: amount is deducted from your main wallet and stored in your Offline Wallet for offline payments only.',
                          style: TextStyle(fontSize: 12, color: _effectiveIsDark ? Colors.grey[400] : Colors.green[800]),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoadOfflineWalletScreen(),
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
                color: _effectiveIsDark ? Colors.grey[850] : Colors.blue[50],
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
                              color: _effectiveIsDark ? null : Colors.blue[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _merchantConnected
                            ? 'Merchant connected to hotspot. Ready for offline transactions.'
                            : 'Turn on your mobile hotspot. Ask merchant to connect to it, then scan their QR.',
                        style: TextStyle(fontSize: 12, color: _effectiveIsDark ? Colors.grey[400] : Colors.blue[800]),
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

              /// ASSETS: when online show main wallet; when offline show only offline balance
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Your Assets (Main Wallet)",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cryptos.length,
                itemBuilder: (context, index) {
                  final c = cryptos[index];
                  final symbol = c["symbol"] as String;
                  final amount = c["amount"] as double;

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: c["color"],
                        child: Image.asset(c["icon"], width: 22),
                      ),
                      title: Text(c["name"]),
                      subtitle: Text(symbol),
                      trailing: Text(
                        amount.toStringAsFixed(symbol == "USDT" ? 2 : 6),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            ),
          ),
        ),

        bottomNavigationBar: widget.embedded
            ? null
            : BottomNavigationBar(
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
    );
    if (widget.embedded) return content;
    return Theme(
      data: isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true),
      child: content,
    );
  }
}
