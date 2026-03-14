import 'dart:math';
import 'package:flutter/material.dart';
import 'payment_success.dart';
import '../services/blockchain_service.dart';
import '../services/local_storage.dart';
import '../services/network_availability_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentPreview extends StatelessWidget {
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

  static String _generateTxId() {
    final t = DateTime.now().millisecondsSinceEpoch;
    final r = Random().nextInt(999999);
    return "offline_${t}_$r";
  }

  Future<void> _confirmPayment(BuildContext context) async {
    final online = await NetworkAvailabilityService.hasInternet();

    if (online) {
      final success = await BlockchainService.sendTransaction(
        address,
        amount,
        crypto,
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
              merchant: address,
              amount: amount,
              token: crypto,
            ),
          ),
        );
      }
      return;
    }

    // Offline: send to merchant local URL if available
    if (localIp != null && localPort != null && localIp!.isNotEmpty) {
      final txId = _generateTxId();
      final payload = {
        OfflineTxKeys.txId: txId,
        OfflineTxKeys.from: BlockchainService.clientAddress,
        OfflineTxKeys.to: address,
        OfflineTxKeys.amount: amount,
        OfflineTxKeys.token: crypto,
        OfflineTxKeys.timestamp: DateTime.now().toIso8601String(),
        OfflineTxKeys.status: "pending",
      };
      try {
        final res = await http.post(
          Uri.parse("http://$localIp:$localPort/receive-payment"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          await LocalStorage.addPendingOfflineTx(payload);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Payment recorded offline. Will sync when online.")),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentSuccess(
                  merchant: address,
                  amount: amount,
                  token: crypto,
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
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Preview")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row("Crypto", crypto),
            _row("Amount", amount.toStringAsFixed(6)),
            _row("To", address),
            if (localIp != null && localPort != null)
              _row("Mode", "Offline (local)"),
            const Spacer(),
            ElevatedButton(
              child: const Text("Confirm Payment"),
              onPressed: () => _confirmPayment(context),
            ),
          ],
        ),
      ),
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
