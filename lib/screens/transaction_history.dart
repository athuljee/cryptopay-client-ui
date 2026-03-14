import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/server_config.dart';

class TransactionHistory extends StatefulWidget {
  const TransactionHistory({super.key});

  @override
  State<TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory> {
  List<Map<String, dynamic>> transactions = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {

    final response = await http.get(
      Uri.parse("${ServerConfig.baseUrl}/chain"),
    );

    if (response.statusCode == 200) {

      final chain = jsonDecode(response.body);

      List<Map<String, dynamic>> txs = [];

      for (var block in chain) {

        if (block["transactions"] is List) {

          for (var tx in block["transactions"]) {

            txs.add(Map<String, dynamic>.from(tx));

          }

        }

      }

      setState(() {

        transactions = txs.reversed.toList();
        loading = false;

      });

    }

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Transaction History")),

      body: RefreshIndicator(

        onRefresh: loadHistory,

        child: loading
            ? const Center(child: CircularProgressIndicator())
            : transactions.isEmpty
            ? const Center(child: Text("No transactions yet"))
            : ListView.builder(

          itemCount: transactions.length,

          itemBuilder: (context, index) {

            final tx = transactions[index];

            return ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(
                "${tx['amount']} ${tx['token']}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "From ${tx['sender']} → ${tx['receiver']}",
              ),
              trailing: const Icon(
                Icons.check_circle,
                color: Colors.green,
              ),
            );

          },

        ),

      ),

    );

  }
}