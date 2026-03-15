import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  String _fmtTime(DateTime? dt) {
    if (dt == null) return "-";
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, "0");
    final ap = dt.hour >= 12 ? "PM" : "AM";
    return "$h:$m $ap";
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return "-";
    return "${dt.year}-${dt.month.toString().padLeft(2, "0")}-${dt.day.toString().padLeft(2, "0")}";
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

  String _modeLabel(Map<String, dynamic> tx) {
    final isOffline = tx["is_offline_payment"] == true;
    return isOffline ? "Offline Payment" : "Online Payment";
  }

  String _statusLabel(Map<String, dynamic> tx) {
    final isOffline = tx["is_offline_payment"] == true;
    if (!isOffline) return "Online";
    final sync = (tx["sync_status"] ?? "pending").toString().toLowerCase();
    if (sync == "synced") return "Synced to Blockchain • Mined";
    if (sync == "failed") return "Failed";
    return "Pending Sync";
  }

  Color _statusColor(Map<String, dynamic> tx) {
    final isOffline = tx["is_offline_payment"] == true;
    if (!isOffline) return const Color(0xFF22C55E);
    final sync = (tx["sync_status"] ?? "pending").toString().toLowerCase();
    if (sync == "synced") return const Color(0xFF3B82F6);
    if (sync == "failed") return const Color(0xFFEF4444);
    return const Color(0xFFEAB308);
  }

  IconData _statusIcon(Map<String, dynamic> tx) {
    final isOffline = tx["is_offline_payment"] == true;
    if (!isOffline) return Icons.cloud_done;
    final sync = (tx["sync_status"] ?? "pending").toString().toLowerCase();
    if (sync == "synced") return Icons.sync;
    if (sync == "failed") return Icons.error_outline;
    return Icons.schedule;
  }

  void _showTransactionDetails(Map<String, dynamic> tx) {
    final createdAt = _parseDate(tx["offline_created_at"]) ?? _parseDate(tx["created_at"]);
    final receivedAt = _parseDate(tx["offline_received_at"]);
    final syncedAt = _parseDate(tx["blockchain_synced_at"]);
    final txId = (tx["tx_id"] ?? tx["txId"] ?? "").toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewPadding.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                "Transaction Details",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _detailRow("Amount", "${tx['amount']} ${tx['token'] ?? 'ETH'}"),
              _detailRow("From", "${tx['sender'] ?? '—'}"),
              _detailRow("To", "${tx['receiver'] ?? '—'}"),
              _detailRow("Mode", _modeLabel(tx)),
              if (txId.isNotEmpty) _detailRow("Transaction ID", txId),
              const Divider(height: 24),
              _detailRow("Created Offline", _fmtTime(createdAt)),
              _detailRow("Merchant Received", _fmtTime(receivedAt ?? createdAt)),
              _detailRow("Synced to Blockchain", _fmtTime(syncedAt)),
              _detailRow("Status", _statusLabel(tx)),
              if (txId.isNotEmpty) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: txId));
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transaction ID copied")));
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text("Copy Transaction ID"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
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
      appBar: AppBar(
        title: const Text("Transaction History"),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: loadHistory,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null && transactions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                    ),
                  )
                : transactions.isEmpty
                    ? const Center(child: Text("No transactions yet"))
                    : CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _legendChip("Online", const Color(0xFF22C55E)),
                                  _legendChip("Offline Pending", const Color(0xFFEAB308)),
                                  _legendChip("Synced", const Color(0xFF3B82F6)),
                                  _legendChip("Failed", const Color(0xFFEF4444)),
                                ],
                              ),
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final tx = transactions[index];
                                final statusColor = _statusColor(tx);
                                final createdAt = _parseDate(tx["offline_created_at"]) ?? _parseDate(tx["created_at"]);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _showTransactionDetails(tx),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.04),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  "Payment Sent",
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(_statusIcon(tx), size: 14, color: statusColor),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        _statusLabel(tx),
                                                        style: TextStyle(
                                                          color: statusColor,
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              "${tx['amount']} ${tx['token'] ?? 'ETH'}",
                                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "To: ${tx['receiver'] ?? '—'}",
                                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Icon(Icons.payment, size: 14, color: Colors.grey.shade600),
                                                const SizedBox(width: 6),
                                                Text(_modeLabel(tx), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                                const SizedBox(width: 16),
                                                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                                const SizedBox(width: 6),
                                                Text(_fmtDate(createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                                const SizedBox(width: 12),
                                                Text(_fmtTime(createdAt), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: transactions.length,
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _legendChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    );
  }
}