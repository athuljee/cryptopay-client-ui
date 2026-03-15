import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys for offline pending transactions (txId, from, to, amount, token, timestamp, status)
class OfflineTxKeys {
  static const txId = "txId";
  static const from = "from";
  static const to = "to";
  static const amount = "amount";
  static const token = "token";
  static const timestamp = "timestamp";
  static const status = "status"; // "pending" | "synced"
  static const syncStatus = "sync_status"; // "pending" | "synced" | "failed"
  static const isOfflinePayment = "is_offline_payment";
  static const offlineCreatedAt = "offline_created_at";
  static const offlineReceivedAt = "offline_received_at";
  static const blockchainSyncedAt = "blockchain_synced_at";
}

class LocalStorage {
  static const _balanceKey = "balances";
  static const _historyKey = "history";
  static const _pendingOfflineKey = "pending_offline_txs";
  static const _offlineBalanceKey = "offline_balances";

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

  // ---------- Offline pending transactions ----------

  static Future<void> addPendingOfflineTx(Map<String, dynamic> tx) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingOfflineKey);
    List list = raw == null ? [] : jsonDecode(raw);
    list.insert(0, tx);
    await prefs.setString(_pendingOfflineKey, jsonEncode(list));
  }

  static Future<List<Map<String, dynamic>>> getPendingOfflineTxs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingOfflineKey);
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> updatePendingTxStatus(String txId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingOfflineKey);
    if (raw == null) return;
    List list = jsonDecode(raw);
    for (int i = 0; i < list.length; i++) {
      if (list[i][OfflineTxKeys.txId] == txId) {
        list[i][OfflineTxKeys.status] = status;
        list[i][OfflineTxKeys.syncStatus] = status == "synced" ? "synced" : status;
        if (status == "synced") {
          list[i][OfflineTxKeys.blockchainSyncedAt] = DateTime.now().toIso8601String();
        }
        break;
      }
    }
    await prefs.setString(_pendingOfflineKey, jsonEncode(list));
  }

  static Future<void> removePendingTx(String txId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingOfflineKey);
    if (raw == null) return;
    List list = jsonDecode(raw);
    list.removeWhere((e) => e[OfflineTxKeys.txId] == txId);
    await prefs.setString(_pendingOfflineKey, jsonEncode(list));
  }

  // ---------- Offline wallet balance (cached for display when offline) ----------

  /// Saved balance that was transferred for offline use. Shown when offline.
  static Future<Map<String, double>> getOfflineBalances() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_offlineBalanceKey);
    if (raw == null) return {"BTC": 0.0, "ETH": 0.0, "USDT": 0.0};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      "BTC": (decoded["BTC"] as num?)?.toDouble() ?? 0.0,
      "ETH": (decoded["ETH"] as num?)?.toDouble() ?? 0.0,
      "USDT": (decoded["USDT"] as num?)?.toDouble() ?? 0.0,
    };
  }

  static Future<void> setOfflineBalances(Map<String, double> balances) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_offlineBalanceKey, jsonEncode(balances));
  }

  /// Call after an offline payment so cached balance reflects the deduction.
  static Future<void> deductOfflineBalance(String token, double amount) async {
    final balances = await getOfflineBalances();
    final key = token.toUpperCase();
    if (balances.containsKey(key)) {
      final current = balances[key]!;
      balances[key] = (current - amount).clamp(0.0, double.infinity);
      await setOfflineBalances(balances);
    }
  }
}
