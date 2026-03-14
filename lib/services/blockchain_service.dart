import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/server_config.dart';

class BlockchainService {

  static  String clientAddress = "";

  static Future<Map<String, dynamic>> getBalance() async {

    final response = await http.get(
      Uri.parse("${ServerConfig.baseUrl}/balance/$clientAddress"),
    );

    return jsonDecode(response.body);
  }

  static Future<bool> sendTransaction(
      String receiver, double amount, String token) async {

    final response = await http.post(
      Uri.parse("${ServerConfig.baseUrl}/transaction"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "sender": clientAddress,
        "receiver": receiver,
        "amount": amount,
        "token": token
      }),
    );

    final data = jsonDecode(response.body);

    return data["success"] == true;
  }

  static Future<void> mineBlock() async {

    await http.get(
      Uri.parse("${ServerConfig.baseUrl}/mine"),
    );

  }
}