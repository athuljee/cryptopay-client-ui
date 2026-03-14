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
      /// JSON QR
      if (raw.startsWith('{')) {
        final data = jsonDecode(raw);

        final crypto = data['crypto'] ?? "";
        final merchant = data['merchant'] ?? "";

        double amount = 0;
        if (data['amount'] != null) {
          amount = (data['amount'] as num).toDouble();
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentPreview(
              crypto: crypto,
              amount: amount,
              address: merchant, // merchant becomes receiver
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
