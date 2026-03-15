import 'package:flutter/material.dart';
import '../services/blockchain_service.dart';
import '../services/offline_server_service.dart';
import '../services/local_storage.dart';
import '../config/server_config.dart';

/// Internal transfer: Main Wallet (Online) → Offline Wallet (same account).
/// This is NOT sending to another user; it moves balance within the same account.
class LoadOfflineWalletScreen extends StatefulWidget {
  const LoadOfflineWalletScreen({super.key});

  @override
  State<LoadOfflineWalletScreen> createState() => _LoadOfflineWalletScreenState();
}

class _LoadOfflineWalletScreenState extends State<LoadOfflineWalletScreen> {
  final _amountController = TextEditingController();
  final _merchantIpController = TextEditingController(text: ServerConfig.localOfflineHost);

  String _token = "ETH";
  bool _loading = false;
  bool _discovering = false;
  Map<String, dynamic>? _offlineWallet;

  @override
  void initState() {
    super.initState();
    _refreshOfflineWallet();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantIpController.dispose();
    super.dispose();
  }

  String? get _merchantIpOverride {
    final raw = _merchantIpController.text.trim();
    return raw.isEmpty ? null : raw;
  }

  Future<void> _refreshOfflineWallet() async {
    if (_merchantIpOverride == null) {
      await _autoDetectMerchant(showMessage: false);
    }
    final wallet = await OfflineServerService.getOfflineWallet(
      BlockchainService.clientAddress,
      merchantIpOverride: _merchantIpOverride,
    );
    if (mounted) setState(() => _offlineWallet = wallet);
  }

  Future<void> _autoDetectMerchant({bool showMessage = true}) async {
    if (_discovering) return;
    setState(() => _discovering = true);
    try {
      final host = await OfflineServerService.discoverOfflineHost(
        merchantIpOverride: _merchantIpOverride,
      );
      if (host != null && host.isNotEmpty) {
        _merchantIpController.text = host;
        ServerConfig.localOfflineHost = host;
        if (showMessage && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Offline server at $host")),
          );
        }
      } else if (showMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not find offline server. Connect to merchant network or enter IP."),
          ),
        );
      }
      await _refreshOfflineWallet();
    } finally {
      if (mounted) setState(() => _discovering = false);
    }
  }

  Future<void> _transferToOfflineWallet() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid amount")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      if (_merchantIpOverride == null) {
        await _autoDetectMerchant(showMessage: true);
      }
      final result = await OfflineServerService.loadOfflineWallet(
        userId: BlockchainService.clientAddress,
        token: _token,
        amount: amount,
        merchantIpOverride: _merchantIpOverride,
      );
      // Persist new offline balance so home shows it (and it's available when offline)
      final wallet = result["wallet"] as Map<String, dynamic>?;
      if (wallet != null && wallet["balances"] is Map) {
        final balances = (wallet["balances"] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v is num ? v.toDouble() : 0.0)),
        );
        await LocalStorage.setOfflineBalances(balances);
      }
      await _refreshOfflineWallet();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Transferred to your offline wallet. Main balance reduced.")),
        );
        _amountController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Transfer failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Load to Offline Wallet"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.swap_vert, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          "Internal transfer (same account)",
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Main Wallet (Online) → Offline Wallet (this device). "
                      "You are not sending to another user; balance stays in your account.",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Amount",
                border: OutlineInputBorder(),
                hintText: "0.00",
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _token,
              decoration: const InputDecoration(
                labelText: "Cryptocurrency",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "ETH", child: Text("ETH")),
                DropdownMenuItem(value: "BTC", child: Text("BTC")),
                DropdownMenuItem(value: "USDT", child: Text("USDT")),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _token = v);
              },
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              "Offline server (where to load)",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              "Connect to the same network as the merchant's offline server to transfer.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _merchantIpController,
              decoration: const InputDecoration(
                labelText: "Offline server IP (optional)",
                hintText: "Leave empty to auto-detect",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _discovering ? null : () => _autoDetectMerchant(showMessage: true),
              icon: _discovering
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search, size: 18),
              label: const Text("Auto-detect offline server"),
            ),
            if (_offlineWallet != null) ...[
              const SizedBox(height: 12),
              Text(
                "Current offline balance: ${((_offlineWallet!["balances"] as Map<String, dynamic>?)?[_token] ?? 0).toString()} $_token",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _loading ? null : _transferToOfflineWallet,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_loading ? "Transferring…" : "Transfer to my offline wallet"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
