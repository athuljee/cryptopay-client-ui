import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/server_config.dart';
import '../services/blockchain_service.dart';
import '../services/offline_server_service.dart';

class SendCryptoScreen extends StatefulWidget {
  /// When non-null, opens in this mode (e.g. local for "Load to offline wallet" flow).
  final ClientSendMode? initialMode;

  const SendCryptoScreen({super.key, this.initialMode});

  @override
  State<SendCryptoScreen> createState() => _SendCryptoScreenState();
}

class _SendCryptoScreenState extends State<SendCryptoScreen> {

  final receiverController = TextEditingController();
  final amountController = TextEditingController();
  final localIpController = TextEditingController(text: ServerConfig.localOfflineHost);

  String token = "ETH";
  late ClientSendMode sendMode;

  bool loading = false;
  bool loadingWallet = false;
  bool discoveringMerchantHost = false;
  Map<String, dynamic>? offlineWallet;

  @override
  void initState() {
    super.initState();
    sendMode = widget.initialMode ?? ClientSendMode.online;
    _refreshOfflineWallet();
  }

  String? _merchantIpOverride() {
    final raw = localIpController.text.trim();
    return raw.isEmpty ? null : raw;
  }

  Future<void> _autoDetectMerchantHost({bool showMessage = false}) async {
    if (discoveringMerchantHost) return;
    setState(() => discoveringMerchantHost = true);
    try {
      final host = await OfflineServerService.discoverOfflineHost(
        merchantIpOverride: _merchantIpOverride(),
      );
      if (host != null && host.isNotEmpty) {
        localIpController.text = host;
        ServerConfig.localOfflineHost = host;
        if (showMessage && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Merchant auto-detected at $host")),
          );
        }
      } else if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not auto-detect merchant. Keep both on same hotspot and retry.")),
        );
      }
    } finally {
      if (mounted) setState(() => discoveringMerchantHost = false);
    }
  }

  Future<void> _refreshOfflineWallet() async {
    if (sendMode == ClientSendMode.local && _merchantIpOverride() == null) {
      await _autoDetectMerchantHost();
    }
    final wallet = await OfflineServerService.getOfflineWallet(
      BlockchainService.clientAddress,
      merchantIpOverride: _merchantIpOverride(),
    );
    if (mounted) {
      setState(() => offlineWallet = wallet);
    }
  }

  Future<void> _loadOfflineWallet() async {
    final amount = double.tryParse(amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid amount to load offline wallet")),
      );
      return;
    }

    setState(() => loadingWallet = true);
    try {
      if (_merchantIpOverride() == null) {
        await _autoDetectMerchantHost(showMessage: true);
      }
      await OfflineServerService.loadOfflineWallet(
        userId: BlockchainService.clientAddress,
        token: token,
        amount: amount,
        merchantIpOverride: _merchantIpOverride(),
      );
      await _refreshOfflineWallet();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Offline wallet loaded successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Offline wallet load failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => loadingWallet = false);
    }
  }

  Future<void> sendCrypto() async {

    final amount = double.tryParse(amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Amount must be greater than zero.")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      if (sendMode == ClientSendMode.online) {
        final response = await http.post(
          Uri.parse("${ServerConfig.baseUrl}/transaction"),
          headers: {"Content-Type": "application/json"},
            body: jsonEncode({
            "sender": BlockchainService.clientAddress,
            "receiver": receiverController.text,
            "amount": amount,
            "token": token
          }),
        );

        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          await http.get(Uri.parse("${ServerConfig.baseUrl}/mine"));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Online transaction successful")),
            );
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data["message"] ?? "Transaction failed")),
            );
          }
        }
      } else {
        if (_merchantIpOverride() == null) {
          await _autoDetectMerchantHost(showMessage: true);
        }
        final result = await OfflineServerService.sendOfflineTransfer(
          fromUserId: BlockchainService.clientAddress,
          toUserId: receiverController.text,
          merchantId: receiverController.text,
          token: token,
          amount: amount,
          merchantIpOverride: _merchantIpOverride(),
        );
        await _refreshOfflineWallet();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Offline transaction recorded (${result["status"]})")),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Transfer failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
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

            const SizedBox(height: 16),
            DropdownButton<ClientSendMode>(
              value: sendMode,
              items: const [
                DropdownMenuItem(value: ClientSendMode.online, child: Text("Send Mode: Online")),
                DropdownMenuItem(value: ClientSendMode.local, child: Text("Send Mode: Local Network (Offline Server)")),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => sendMode = v);
                  if (v == ClientSendMode.local) {
                    _autoDetectMerchantHost();
                  }
                }
              },
            ),

            if (sendMode == ClientSendMode.local) ...[
              const SizedBox(height: 12),
              TextField(
                controller: localIpController,
                decoration: const InputDecoration(
                  labelText: "Merchant Local IP (optional)",
                  helperText: "Leave empty for auto-detect. Offline server uses port 3001.",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: discoveringMerchantHost
                      ? null
                      : () => _autoDetectMerchantHost(showMessage: true),
                  icon: discoveringMerchantHost
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search, size: 16),
                  label: const Text("Auto Detect Merchant"),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Offline wallet ${token}: ${((offlineWallet?["balances"] as Map<String, dynamic>?)?[token] ?? 0).toString()}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: loadingWallet ? null : _refreshOfflineWallet,
                      child: const Text("Refresh Offline Wallet"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: loadingWallet ? null : _loadOfflineWallet,
                      child: loadingWallet
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Load Offline Wallet"),
                    ),
                  ),
                ],
              ),
            ],

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