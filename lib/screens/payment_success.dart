import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/server_config.dart';

class PaymentSuccess extends StatefulWidget {

  final String merchant;
  final double amount;
  final String token;

  const PaymentSuccess({
    super.key,
    required this.merchant,
    required this.amount,
    required this.token,
  });

  @override
  State<PaymentSuccess> createState() => _PaymentSuccessState();
}

class _PaymentSuccessState extends State<PaymentSuccess> {

  @override
  void initState() {
    super.initState();
    notifyMerchant();
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

    Future.delayed(const Duration(seconds: 2), () {

      Navigator.pushNamedAndRemoveUntil(
        context,
        "/home",
            (_) => false,
      );

    });

  }

  @override
  Widget build(BuildContext context) {

    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Icon(
              Icons.check_circle,
              size: 120,
              color: Colors.green,
            ),

            SizedBox(height: 20),

            Text(
              "Payment Successful",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

          ],
        ),
      ),
    );

  }
}