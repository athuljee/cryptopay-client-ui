import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../config/server_config.dart';
import 'local_storage.dart';
import 'network_availability_service.dart';

/// Syncs pending offline transactions to the blockchain when internet (backend) is reachable.
class OfflineSyncService {
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static bool _isSyncing = false;

  static void startListening() {
    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen((_) async {
      if (await NetworkAvailabilityService.hasInternet()) {
        syncPendingTransactions();
      }
    });
    syncPendingTransactions();
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  static Future<void> syncPendingTransactions() async {
    if (_isSyncing) return;
    final pending = await LocalStorage.getPendingOfflineTxs();
    if (pending.isEmpty) return;

    if (!await NetworkAvailabilityService.hasInternet()) return;

    _isSyncing = true;
    try {
      for (final tx in pending) {
        if (tx[OfflineTxKeys.status] == "synced") continue;
        final txId = tx[OfflineTxKeys.txId] as String?;
        if (txId == null || txId.isEmpty) continue;

        try {
          final existsRes = await http.get(
            Uri.parse("${ServerConfig.baseUrl}/transaction/exists/$txId"),
          );
          if (existsRes.statusCode == 200) {
            final data = jsonDecode(existsRes.body);
            if (data["exists"] == true) {
              await LocalStorage.updatePendingTxStatus(txId, "synced");
              continue;
            }
          }
        } catch (_) {
          continue;
        }

        try {
          final body = {
            "sender": tx[OfflineTxKeys.from],
            "receiver": tx[OfflineTxKeys.to],
            "amount": tx[OfflineTxKeys.amount],
            "token": tx[OfflineTxKeys.token],
            "txId": txId,
          };
          final postRes = await http.post(
            Uri.parse("${ServerConfig.baseUrl}/transaction"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          );
          if (postRes.statusCode == 200) {
            final data = jsonDecode(postRes.body);
            if (data["success"] == true) {
              await http.get(Uri.parse("${ServerConfig.baseUrl}/mine"));
              await LocalStorage.updatePendingTxStatus(txId, "synced");
            }
          }
        } catch (_) {}
      }
    } finally {
      _isSyncing = false;
    }
  }
}
