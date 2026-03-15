import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TrendingPage extends StatefulWidget {
  const TrendingPage({super.key});

  @override
  State<TrendingPage> createState() => _TrendingPageState();
}

class _TrendingPageState extends State<TrendingPage> {
  List<Map<String, dynamic>> coins = [];
  bool loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    loadTrending();

    // 🔁 Auto refresh every 1 minute
    _timer = Timer.periodic(
      const Duration(minutes: 1),
          (_) => loadTrending(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> loadTrending() async {
    try {
      final res = await http.get(
        Uri.parse(
          "https://api.coingecko.com/api/v3/simple/price"
              "?ids=bitcoin,ethereum,tether,solana,ripple"
              "&vs_currencies=usd"
              "&include_24hr_change=true",
        ),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        coins = [
          buildCoin("Bitcoin", "BTC", data["bitcoin"]),
          buildCoin("Ethereum", "ETH", data["ethereum"]),
          buildCoin("Tether", "USDT", data["tether"]),
          buildCoin("Solana", "SOL", data["solana"]),
          buildCoin("XRP", "XRP", data["ripple"]),
        ];

        // Cache locally for offline use
        final prefs = await SharedPreferences.getInstance();
        prefs.setString("cached_trending", jsonEncode(coins));
      }
    } catch (_) {
      // 📦 Offline fallback
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString("cached_trending");
      if (cached != null) {
        coins = List<Map<String, dynamic>>.from(jsonDecode(cached));
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Map<String, dynamic> buildCoin(
      String name,
      String symbol,
      Map<String, dynamic> data,
      ) {
    return {
      "name": name,
      "symbol": symbol,
      "price": (data["usd"] as num).toDouble(),
      "change": (data["usd_24h_change"] as num).toDouble(),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trending Tokens"),
      ),
      body: RefreshIndicator(
        onRefresh: loadTrending,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: coins.length,
        itemBuilder: (context, index) {
          final c = coins[index];
          final isUp = c["change"] >= 0;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              leading: Image.asset(
                'assets/icons/${c["symbol"].toLowerCase()}.png',
                width: 32,
                height: 32,
              ),
              title: Text(c["name"]),
              subtitle: Text(
                "\$${c["price"].toStringAsFixed(2)}",
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: Text(
                "${c["change"].toStringAsFixed(2)}%",
                style: TextStyle(
                  color: isUp ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}
