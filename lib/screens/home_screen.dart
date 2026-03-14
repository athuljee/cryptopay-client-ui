import 'package:flutter/material.dart';
import '../services/blockchain_service.dart';
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

              const SizedBox(height: 20),

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
