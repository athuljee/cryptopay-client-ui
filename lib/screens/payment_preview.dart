import 'dart:math';
import 'package:flutter/material.dart';
import 'payment_success.dart';
import '../services/blockchain_service.dart';
import '../services/local_storage.dart';
import '../services/network_availability_service.dart';
import '../services/offline_server_service.dart';
import '../services/local_merchant_discovery_service_io.dart' if (dart.library.html) '../services/local_merchant_discovery_service_stub.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentPreview extends StatefulWidget {
  final String crypto;
  final String address;
  final double amount;
  final String? localIp;
  final int? localPort;

  const PaymentPreview({
    super.key,
    required this.crypto,
    required this.address,
    required this.amount,
    this.localIp,
    this.localPort,
  });

  @override
  State<PaymentPreview> createState() => _PaymentPreviewState();
}

class _PaymentPreviewState extends State<PaymentPreview> {
  bool _isProcessing = false;

  static String _generateTxId() {
    final t = DateTime.now().millisecondsSinceEpoch;
    final r = Random().nextInt(999999);
    return "offline_${t}_$r";
  }

  Future<void> _confirmPayment(BuildContext context) async {
    if (_isProcessing) return;
    final online = await NetworkAvailabilityService.hasInternet();

    if (online) {
      final success = await BlockchainService.sendTransaction(
        widget.address,
        widget.amount,
        widget.crypto,
      );
      if (!success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Insufficient balance or invalid amount")),
          );
        }
        return;
      }
      await BlockchainService.mineBlock();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentSuccess(
              merchant: widget.address,
              amount: widget.amount,
              token: widget.crypto,
            ),
          ),
        );
      }
      return;
    }

    // Offline local-network mode: prefer offline server (port 3001), then legacy merchant local endpoint.
    final String? offlineServerIp = widget.localIp;
    if (context.mounted) {
      setState(() => _isProcessing = true);
    }
    try {
      final result = await OfflineServerService.sendOfflineTransfer(
        fromUserId: BlockchainService.clientAddress,
        toUserId: widget.address,
        merchantId: widget.address,
        token: widget.crypto,
        amount: widget.amount,
        merchantIpOverride: offlineServerIp,
      );
      final txId = result["txId"] as String? ?? _generateTxId();
      final payload = {
        OfflineTxKeys.txId: txId,
        OfflineTxKeys.from: BlockchainService.clientAddress,
        OfflineTxKeys.to: widget.address,
        OfflineTxKeys.amount: widget.amount,
        OfflineTxKeys.token: widget.crypto,
        OfflineTxKeys.timestamp: DateTime.now().toIso8601String(),
        OfflineTxKeys.status: "pending",
        OfflineTxKeys.syncStatus: "pending",
        OfflineTxKeys.isOfflinePayment: true,
        OfflineTxKeys.offlineCreatedAt: DateTime.now().toIso8601String(),
        OfflineTxKeys.offlineReceivedAt: DateTime.now().toIso8601String(),
      };
      await LocalStorage.addPendingOfflineTx(payload);
      await LocalStorage.deductOfflineBalance(widget.crypto, widget.amount);
      if (context.mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Offline payment recorded. Will sync when online.")),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentSuccess(
              merchant: widget.address,
              amount: widget.amount,
              token: widget.crypto,
              offline: true,
            ),
          ),
        );
      }
      return;
    } catch (_) {
      if (context.mounted) setState(() => _isProcessing = false);
      // Fallback to legacy local merchant endpoint for compatibility.
    }

    // Legacy fallback: send to merchant local URL. If QR has no localIp, auto-discover merchant on same hotspot.
    final int targetPort = widget.localPort ?? 8765;
    String? targetIp = widget.localIp;
    if (targetIp == null || targetIp.isEmpty) {
      targetIp = await LocalMerchantDiscoveryService.discoverMerchantIp(
        port: targetPort,
        hintedIp: widget.localIp,
      );
    }
    if (targetIp != null && targetIp.isNotEmpty) {
      if (context.mounted) setState(() => _isProcessing = true);
      final txId = _generateTxId();
      final payload = {
        OfflineTxKeys.txId: txId,
        OfflineTxKeys.from: BlockchainService.clientAddress,
        OfflineTxKeys.to: widget.address,
        OfflineTxKeys.amount: widget.amount,
        OfflineTxKeys.token: widget.crypto,
        OfflineTxKeys.timestamp: DateTime.now().toIso8601String(),
        OfflineTxKeys.status: "pending",
        OfflineTxKeys.syncStatus: "pending",
        OfflineTxKeys.isOfflinePayment: true,
        OfflineTxKeys.offlineCreatedAt: DateTime.now().toIso8601String(),
        OfflineTxKeys.offlineReceivedAt: DateTime.now().toIso8601String(),
      };
      try {
        final res = await http.post(
          Uri.parse("http://$targetIp:$targetPort/receive-payment"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 10));
        if (context.mounted) setState(() => _isProcessing = false);
        if (res.statusCode == 200) {
          await LocalStorage.addPendingOfflineTx(payload);
          await LocalStorage.deductOfflineBalance(widget.crypto, widget.amount);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Payment recorded offline. Will sync when online.")),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentSuccess(
                  merchant: widget.address,
                  amount: widget.amount,
                  token: widget.crypto,
                  offline: true,
                ),
              ),
            );
          }
          return;
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Merchant could not accept payment. Try again.")),
          );
        }
        return;
      } catch (e) {
        if (context.mounted) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Offline payment failed: $e")),
          );
        }
        return;
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No internet and no local merchant. Connect or use merchant's offline QR.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text("Payment Preview")),
          body: RefreshIndicator(
            onRefresh: () async {},
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                _row("Crypto", widget.crypto),
                _row("Amount", widget.amount.toStringAsFixed(6)),
                _row("To", widget.address),
                if (widget.localIp != null && widget.localPort != null)
                  _row("Mode", "Offline (local)"),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isProcessing ? null : () => _confirmPayment(context),
                  child: const Text("Confirm Payment"),
                ),
                ],
              ),
            ),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black26,
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(32),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        "Sending Payment…",
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _row(String t, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(t, style: const TextStyle(color: Colors.grey)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
