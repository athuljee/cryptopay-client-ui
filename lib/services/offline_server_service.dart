import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/server_config.dart';
import 'local_merchant_discovery_service_io.dart'
    if (dart.library.html) 'local_merchant_discovery_service_stub.dart';

enum ClientSendMode { online, local }

class OfflineServerService {
  static Future<String?> discoverOfflineHost({String? merchantIpOverride}) async {
    if (merchantIpOverride != null && merchantIpOverride.trim().isNotEmpty) {
      return merchantIpOverride.trim();
    }
    if (ServerConfig.localOfflineHost.trim().isNotEmpty) {
      return ServerConfig.localOfflineHost.trim();
    }
    return await LocalMerchantDiscoveryService.discoverMerchantIp(
      port: ServerConfig.localOfflinePort,
      hintedIp: null,
    );
  }

  static Future<String> _resolveLocalBaseUrl({String? merchantIpOverride}) async {
    final host = await discoverOfflineHost(merchantIpOverride: merchantIpOverride);
    if (host == null || host.isEmpty) {
      throw Exception("No local merchant offline server found on WLAN");
    }
    return "http://$host:${ServerConfig.localOfflinePort}";
  }

  static Future<Map<String, dynamic>?> getOfflineWallet(
    String userId, {
    String? merchantIpOverride,
  }) async {
    try {
      final base = await _resolveLocalBaseUrl(merchantIpOverride: merchantIpOverride);
      final res = await http
          .get(Uri.parse("$base/offline-wallet/$userId"))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data["wallet"] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> loadOfflineWallet({
    required String userId,
    required String token,
    required double amount,
    String? merchantIpOverride,
  }) async {
    final base = await _resolveLocalBaseUrl(merchantIpOverride: merchantIpOverride);
    final res = await http
        .post(
          Uri.parse("$base/offline-wallet/load"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "userId": userId,
            "token": token,
            "amount": amount,
          }),
        )
        .timeout(const Duration(seconds: 10));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300 && data["ok"] == true) {
      return data;
    }
    throw Exception(data["error"] ?? "offline_wallet_load_failed");
  }

  static Future<Map<String, dynamic>> sendOfflineTransfer({
    required String fromUserId,
    required String toUserId,
    required String merchantId,
    required String token,
    required double amount,
    String? merchantIpOverride,
  }) async {
    final base = await _resolveLocalBaseUrl(merchantIpOverride: merchantIpOverride);
    final wallet = await getOfflineWallet(
      fromUserId,
      merchantIpOverride: merchantIpOverride,
    );
    final currentNonce = (wallet?["nonce"] as num?)?.toInt() ?? 0;

    final res = await http
        .post(
          Uri.parse("$base/offline-transfer"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "fromUserId": fromUserId,
            "toUserId": toUserId,
            "merchantId": merchantId,
            "token": token,
            "amount": amount,
            "nonce": currentNonce + 1,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300 && data["ok"] == true) {
      return data;
    }
    throw Exception(data["error"] ?? "offline_transfer_failed");
  }
}
