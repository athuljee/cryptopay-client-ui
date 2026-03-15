import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'payment_preview.dart';

class QRScanPage extends StatefulWidget {
  const QRScanPage({super.key});

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  final MobileScannerController controller = MobileScannerController();
  bool _busy = false;

  void _handle(String raw) {
    if (_busy) return;
    _busy = true;

    try {
      /// JSON QR from merchant terminal (merchant, crypto, amount; optional localIp, port for offline)
      if (raw.startsWith('{')) {
        final data = jsonDecode(raw) as Map<String, dynamic>?;
        if (data == null) throw Exception("Invalid QR");

        final crypto = (data['crypto'] ?? data['token'] ?? "").toString();
        final merchant = (data['merchant'] ?? data['address'] ?? "").toString();

        double amount = 0;
        final amountVal = data['amount'] ?? data['cryptoAmount'];
        if (amountVal != null) amount = (amountVal as num).toDouble();

        final localIp = data['localIp'] as String?;
        final port = data['port'] != null ? (data['port'] as num).toInt() : null;
        final mode = data['mode']?.toString();
        final isOfflineFlow = port != null || mode == 'offline_server';

        final cryptoType = crypto.isNotEmpty ? crypto : "ETH";

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentPreview(
              crypto: cryptoType,
              amount: amount,
              address: merchant,
              merchantName: merchant.isNotEmpty ? merchant : null,
              localIp: localIp,
              localPort: port,
              isOfflineFlow: isOfflineFlow,
            ),
          ),
        );
        return;
      }

      /// Ethereum
      if (raw.startsWith("ethereum:")) {
        final uri = Uri.parse(raw);
        final address = uri.path;
        final wei = uri.queryParameters["value"] ?? "0";
        final eth = double.parse(wei) / 1e18;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentPreview(
              crypto: "ETH",
              amount: eth,
              address: address,
            ),
          ),
        );
        return;
      }

      /// Bitcoin
      if (raw.startsWith("bitcoin:")) {
        final uri = Uri.parse(raw);
        final address = uri.path;
        final btc =
            double.tryParse(uri.queryParameters["amount"] ?? "0") ?? 0;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentPreview(
              crypto: "BTC",
              amount: btc,
              address: address,
            ),
          ),
        );
        return;
      }

      throw Exception("Unsupported QR");
    } catch (e) {
      _busy = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid QR")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan QR")),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          if (capture.barcodes.isEmpty) return;

          final code = capture.barcodes.first.rawValue;

          if (code == null || code.isEmpty) return;

          _handle(code);
          }
      ),
    );
  }
}
