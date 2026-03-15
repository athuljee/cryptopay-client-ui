import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/server_config.dart';
import '../services/blockchain_service.dart';
import '../services/local_storage.dart';
import '../services/offline_server_service.dart';

class TransactionHistory extends StatefulWidget {
  const TransactionHistory({super.key});

  @override
  State<TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory> {
  List<Map<String, dynamic>> transactions = [];
  bool loading = true;
  String? errorMessage;
  String currentUser = "";

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final s = value.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return "-";
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, "0");
    final ap = dt.hour >= 12 ? "PM" : "AM";
    return "$h:$m $ap";
  }

  Map<String, dynamic> _normalizeOnline(Map<String, dynamic> tx) {
    final txId = tx["tx_id"] ?? tx["txId"];
    final isOffline = tx["is_offline_payment"] == true;
    return {
      "tx_id": txId ?? "online_${tx.hashCode}",
      "sender": tx["sender"],
      "receiver": tx["receiver"],
      "amount": tx["amount"],
      "token": tx["token"],
      "is_offline_payment": isOffline,
      "sync_status": isOffline ? (tx["sync_status"] ?? "synced") : "synced",
      "offline_created_at": tx["offline_created_at"],
      "offline_received_at": tx["offline_received_at"],
      "blockchain_synced_at": tx["blockchain_synced_at"],
      "created_at": tx["timestamp"] ?? tx["created_at"],
      "source": "online",
    };
  }

  Map<String, dynamic> _normalizeOffline(Map<String, dynamic> tx) {
    return {
      "tx_id": tx["tx_id"] ?? tx["txId"] ?? "offline_${tx.hashCode}",
      "sender": tx["from_user_id"] ?? tx["sender"] ?? tx["from"],
      "receiver": tx["to_user_id"] ?? tx["receiver"] ?? tx["to"],
      "amount": tx["amount"],
      "token": tx["token"],
      "is_offline_payment": true,
      "sync_status": tx["sync_status"] ?? tx["status"] ?? "pending",
      "offline_created_at": tx["offline_created_at"] ?? tx["timestamp"] ?? tx["created_at"],
      "offline_received_at": tx["offline_received_at"] ?? tx["created_at"] ?? tx["timestamp"],
      "blockchain_synced_at": tx["blockchain_synced_at"] ?? tx["synced_at"],
      "created_at": tx["created_at"] ?? tx["timestamp"],
      "source": "offline",
    };
  }

  int _rank(Map<String, dynamic> tx) {
    final sync = (tx["sync_status"] ?? "").toString().toLowerCase();
    if (sync == "synced") return 3;
    if (sync == "failed") return 2;
    if (sync == "pending") return 1;
    return 0;
  }

  String _label(Map<String, dynamic> tx) {
    final isOffline = tx["is_offline_payment"] == true;
    if (!isOffline) return "Online Payment";
    final sync = (tx["sync_status"] ?? "pending").toString().toLowerCase();
    if (sync == "synced") return "Offline Payment (Synced)";
    if (sync == "failed") return "Offline Payment (Failed)";
    return "Offline Payment (Pending Sync)";
  }

  Color _badgeColor(Map<String, dynamic> tx) {
    final isOffline = tx["is_offline_payment"] == true;
    if (!isOffline) return Colors.green;
    final sync = (tx["sync_status"] ?? "pending").toString().toLowerCase();
    if (sync == "synced") return Colors.blue;
    if (sync == "failed") return Colors.redAccent;
    return Colors.orange;
  }

  Future<void> loadHistory() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      currentUser = prefs.getString("user") ?? BlockchainService.clientAddress;

      final merged = <String, Map<String, dynamic>>{};
      final response = await http.get(
        Uri.parse("${ServerConfig.baseUrl}/chain"),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final chain = jsonDecode(response.body);
        if (chain is List) {
          for (var block in chain) {
            if (block is Map && block["transactions"] is List) {
              for (var raw in block["transactions"] as List) {
                if (raw is! Map) continue;
                final tx = _normalizeOnline(Map<String, dynamic>.from(raw));
                final txId = tx["tx_id"].toString();
                final old = merged[txId];
                if (old == null || _rank(tx) >= _rank(old)) {
                  merged[txId] = tx;
                }
              }
            }
          }
        }
      }

      final offline = await OfflineServerService.getOfflineTransactions(
        userId: currentUser,
      );
      for (final raw in offline) {
        final tx = _normalizeOffline(raw);
        final txId = tx["tx_id"].toString();
        final old = merged[txId];
        if (old == null || _rank(tx) >= _rank(old)) {
          merged[txId] = tx;
        }
      }

      final pending = await LocalStorage.getPendingOfflineTxs();
      for (final raw in pending) {
        final tx = _normalizeOffline(raw);
        final txId = tx["tx_id"].toString();
        final old = merged[txId];
        if (old == null || _rank(tx) >= _rank(old)) {
          merged[txId] = tx;
        }
      }

      final txs = merged.values.toList()
        ..sort((a, b) {
          final ad = _parseDate(a["offline_created_at"]) ??
              _parseDate(a["created_at"]) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bd = _parseDate(b["offline_created_at"]) ??
              _parseDate(b["created_at"]) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
      if (mounted) {
        setState(() {
          transactions = txs;
          loading = false;
          errorMessage = txs.isEmpty ? "No transactions yet." : null;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Client TransactionHistory loadHistory: $e");
      final pending = await LocalStorage.getPendingOfflineTxs();
      final txs = pending.map(_normalizeOffline).toList();
      if (mounted) {
        setState(() {
          transactions = txs;
          loading = false;
          errorMessage = txs.isEmpty ? "No internet. No local transactions available." : "No internet. Showing offline transactions.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Transaction History")),

      body: RefreshIndicator(

        onRefresh: loadHistory,

        child: loading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null && transactions.isEmpty
            ? Center(child: Text(errorMessage!, textAlign: TextAlign.center))
            : transactions.isEmpty
            ? const Center(child: Text("No transactions yet"))
            : ListView.builder(

          itemCount: transactions.length,

          itemBuilder: (context, index) {

            final tx = transactions[index];
            final badgeColor = _badgeColor(tx);
            final createdAt = _parseDate(tx["offline_created_at"]) ?? _parseDate(tx["created_at"]);
            final receivedAt = _parseDate(tx["offline_received_at"]);
            final syncedAt = _parseDate(tx["blockchain_synced_at"]);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Payment Sent",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _label(tx),
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text("Amount: ${tx['amount']} ${tx['token']}"),
                    Text("From: ${tx['sender']}  To: ${tx['receiver']}"),
                    const SizedBox(height: 8),
                    Text("Created (Offline): ${_fmt(createdAt)}", style: const TextStyle(fontSize: 12)),
                    Text("Merchant Received: ${_fmt(receivedAt ?? createdAt)}", style: const TextStyle(fontSize: 12)),
                    Text("Synced to Blockchain: ${_fmt(syncedAt)}", style: const TextStyle(fontSize: 12)),
                    if ((tx["tx_id"] ?? "").toString().isNotEmpty)
                      Text("tx_id: ${tx["tx_id"]}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            );

          },

        ),

      ),

    );

  }
}