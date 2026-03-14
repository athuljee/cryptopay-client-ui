import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _balanceKey = "balances";
  static const _historyKey = "history";

  /// Demo wallet (large balance for testing)
  //static const Map<String, double> demoBalances = {
  //  "BTC": 0.0523,
  //  "ETH": 1.1731,
//  "USDT": 5000.0,   // 💰 FIXED
  // };

  /// Initialize demo wallet only once
  // static Future<void> initDemoBalance() async {
  //  final prefs = await SharedPreferences.getInstance();
  // if (!prefs.containsKey(_balanceKey)) {
//   await prefs.setString(_balanceKey, jsonEncode(demoBalances));
//  }
  // }

  /// Reset wallet to demo values
  //static Future<void> resetWallet() async {
  // final prefs = await SharedPreferences.getInstance();
  // await prefs.setString(_balanceKey, jsonEncode(demoBalances));
// await prefs.remove(_historyKey);
  // }

  /// Read balances
  //static Future<Map<String, double>> getBalances() async {
  // final prefs = await SharedPreferences.getInstance();
  // final raw = prefs.getString(_balanceKey);

  //if (raw == null) return Map<String, double>.from(demoBalances);

  // final decoded = jsonDecode(raw) as Map<String, dynamic>;

//return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
  //}

  /// Deduct crypto on payment
  //static Future<bool> deductBalance(String crypto, double amount) async {
  //final prefs = await SharedPreferences.getInstance();
  //final balances = await getBalances();

  //final current = balances[crypto] ?? 0.0;

  //if (current < amount) return false;

  //balances[crypto] = double.parse((current - amount).toStringAsFixed(8));

  //await prefs.setString(_balanceKey, jsonEncode(balances));
//return true;
  //}

  /// Save transaction
  static Future<void> addTransaction(Map<String, dynamic> tx) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);

    List list = raw == null ? [] : jsonDecode(raw);
    list.insert(0, tx);

    await prefs.setString(_historyKey, jsonEncode(list));
  }

  /// Load transaction history
  static Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);

    if (raw == null) return [];

    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }
}
