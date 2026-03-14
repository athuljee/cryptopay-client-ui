import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/server_config.dart';
import '../services/blockchain_service.dart';

class SendCryptoScreen extends StatefulWidget {
  const SendCryptoScreen({super.key});

  @override
  State<SendCryptoScreen> createState() => _SendCryptoScreenState();
}

class _SendCryptoScreenState extends State<SendCryptoScreen> {

  final receiverController = TextEditingController();
  final amountController = TextEditingController();

  String token = "ETH";

  bool loading = false;

  Future<void> sendCrypto() async {

    setState(() => loading = true);

    final response = await http.post(
      Uri.parse("${ServerConfig.baseUrl}/transaction"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "sender": BlockchainService.clientAddress,
        "receiver": receiverController.text,
        "amount": double.parse(amountController.text),
        "token": token
      }),
    );

    final data = jsonDecode(response.body);

    if (data["success"] == true) {

      // ⭐ MINE BLOCK AFTER TRANSACTION
      await http.get(
        Uri.parse("${ServerConfig.baseUrl}/mine"),
      );

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Transaction successful")),
      );

      Navigator.pop(context);

    } else {

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data["message"] ?? "Transaction failed")),
      );

    }

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Send Crypto")),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            TextField(
              controller: receiverController,
              decoration: const InputDecoration(
                labelText: "Receiver Username",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Amount",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            DropdownButton<String>(
              value: token,
              items: const [
                DropdownMenuItem(value: "ETH", child: Text("ETH")),
                DropdownMenuItem(value: "BTC", child: Text("BTC")),
                DropdownMenuItem(value: "USDT", child: Text("USDT")),
              ],
              onChanged: (v) {
                setState(() => token = v!);
              },
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : sendCrypto,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Send"),
              ),
            ),

          ],
        ),
      ),
    );
  }
}