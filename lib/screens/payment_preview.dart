import 'package:flutter/material.dart';
import 'payment_success.dart';
import '../services/blockchain_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/server_config.dart';

class PaymentPreview extends StatelessWidget {
  final String crypto;
  final String address;
  final double amount;

  const PaymentPreview({
    super.key,
    required this.crypto,
    required this.address,
    required this.amount,
  });

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
            const Spacer(),
            ElevatedButton(
              child: const Text("Confirm Payment"),
              onPressed: () async {
                final success = await BlockchainService.sendTransaction(
                  address,
                  amount,
                  crypto,
                );

                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Insufficient balance")),
                  );
                  return;
                }

                await BlockchainService.mineBlock();

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>  PaymentSuccess(
                      merchant: address,
                      amount: amount,
                      token: crypto,
                    ),
                  ),
                );
              },
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
