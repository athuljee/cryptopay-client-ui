import 'dart:io';
import 'package:http/http.dart' as http;

class LocalMerchantDiscoveryService {
  static bool _isLoopback(String ip) => ip == "127.0.0.1" || ip.startsWith("127.");

  static bool _isPrivate(String ip) {
    return ip.startsWith("192.168.") || ip.startsWith("10.") || ip.startsWith("172.") || ip.startsWith("169.254.");
  }

  static Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: true,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (_isLoopback(ip)) continue;
          if (_isPrivate(ip)) return ip;
        }
      }
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (_isLoopback(ip)) continue;
          return ip;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> _isMerchantAt(String ip, int port) async {
    try {
      final res = await http
          .get(Uri.parse("http://$ip:$port/ping"))
          .timeout(const Duration(milliseconds: 700));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> discoverMerchantIp({
    required int port,
    String? hintedIp,
  }) async {
    if (hintedIp != null && hintedIp.isNotEmpty) {
      if (await _isMerchantAt(hintedIp, port)) return hintedIp;
    }
    final localIp = await _getLocalIp();
    if (localIp == null) return null;

    final parts = localIp.split(".");
    if (parts.length != 4) return null;
    final subnet = "${parts[0]}.${parts[1]}.${parts[2]}";
    final myOctet = int.tryParse(parts[3]);

    final priority = <String>[
      "$subnet.1",
      "$subnet.2",
      "$subnet.10",
      "$subnet.100",
      "$subnet.101",
    ];

    if (myOctet != null) {
      for (int delta = 1; delta <= 15; delta++) {
        final lower = myOctet - delta;
        final higher = myOctet + delta;
        if (lower >= 1) priority.add("$subnet.$lower");
        if (higher <= 254) priority.add("$subnet.$higher");
      }
    }

    final seen = <String>{};
    for (final ip in priority) {
      if (!seen.add(ip)) continue;
      if (await _isMerchantAt(ip, port)) return ip;
    }

    const batchSize = 24;
    final remaining = <String>[];
    for (int i = 1; i <= 254; i++) {
      if (i == myOctet) continue;
      final ip = "$subnet.$i";
      if (seen.contains(ip)) continue;
      remaining.add(ip);
    }

    for (int i = 0; i < remaining.length; i += batchSize) {
      final batch = remaining.skip(i).take(batchSize).toList();
      final results = await Future.wait(
        batch.map((ip) async => await _isMerchantAt(ip, port) ? ip : null),
      );
      for (final hit in results) {
        if (hit != null) return hit;
      }
    }
    return null;
  }
}
