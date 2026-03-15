import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/server_config.dart';

class PaymentSuccess extends StatefulWidget {

  final String merchant;
  final double amount;
  final String token;
  final bool offline;

  const PaymentSuccess({
    super.key,
    required this.merchant,
    required this.amount,
    required this.token,
    this.offline = false,
  });

  @override
  State<PaymentSuccess> createState() => _PaymentSuccessState();
}

class _PaymentSuccessState extends State<PaymentSuccess> {

  @override
  void initState() {
    super.initState();
    if (!widget.offline) notifyMerchant();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          "/home",
          (_) => false,
        );
      }
    });
  }

  Future<void> notifyMerchant() async {
    try {
      await http.post(
        Uri.parse("${ServerConfig.baseUrl}/notify-payment"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "receiver": widget.merchant,
          "amount": widget.amount,
          "token": widget.token
        }),
      );
    } catch (e) {
      print("Notification error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              size: 120,
              color: Colors.green,
            ),
            const SizedBox(height: 20),
            Text(
              widget.offline ? "Payment Sent Successfully" : "Payment Successful",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.offline) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Status: Pending Sync",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}