import 'package:flutter/material.dart';
import '../services/local_storage.dart';

/// Tab screen: offline wallet balance and recent offline transactions.
class OfflineWalletScreen extends StatefulWidget {
  const OfflineWalletScreen({super.key});

  @override
  State<OfflineWalletScreen> createState() => _OfflineWalletScreenState();
}

class _OfflineWalletScreenState extends State<OfflineWalletScreen> {
  Map<String, double> _balances = {"BTC": 0.0, "ETH": 0.0, "USDT": 0.0};
  List<Map<String, dynamic>> _recentTxs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final balances = await LocalStorage.getOfflineBalances();
    final pending = await LocalStorage.getPendingOfflineTxs();
    if (mounted) {
      setState(() {
        _balances = balances;
        _recentTxs = pending.take(10).toList();
        _loading = false;
      });
    }
  }

  double get _totalUsd {
    const prices = {"BTC": 52000.0, "ETH": 3400.0, "USDT": 1.0};
    return _balances.entries.fold(0.0, (s, e) => s + (e.value * (prices[e.key] ?? 0)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Offline Wallet"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Offline Wallet",
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Balance transferred for offline use. Available when paying without internet.",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 20),
                            _balanceRow("BTC", _balances["BTC"] ?? 0, 6),
                            const SizedBox(height: 12),
                            _balanceRow("ETH", _balances["ETH"] ?? 0, 6),
                            const SizedBox(height: 12),
                            _balanceRow("USDT", _balances["USDT"] ?? 0, 2),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.check_circle, size: 18, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  "Available for Offline Payments",
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Total (approx.): \$${_totalUsd.toStringAsFixed(2)}",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Recent Offline Transactions",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_recentTxs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          "No offline transactions yet.",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentTxs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final tx = _recentTxs[i];
                          final amount = (tx["amount"] is num) ? (tx["amount"] as num).toDouble() : 0.0;
                          final token = tx["token"]?.toString() ?? "ETH";
                          final status = tx["sync_status"] ?? tx["status"] ?? "pending";
                          return Card(
                            child: ListTile(
                              title: Text("${amount.toStringAsFixed(token == "USDT" ? 2 : 6)} $token"),
                              subtitle: Text("To: ${tx["to"] ?? "—"} · ${status.toString().toUpperCase()}"),
                              trailing: Icon(
                                status == "synced" ? Icons.cloud_done : Icons.schedule,
                                size: 20,
                                color: status == "synced" ? Colors.green : Colors.orange,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _balanceRow(String crypto, double amount, int decimals) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Crypto: $crypto", style: Theme.of(context).textTheme.bodyLarge),
        Text(
          "Balance: ${amount.toStringAsFixed(decimals)} $crypto",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
