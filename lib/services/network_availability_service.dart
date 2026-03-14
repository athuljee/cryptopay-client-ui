import 'package:http/http.dart' as http;
import '../config/server_config.dart';

/// Checks actual internet availability by pinging the blockchain backend.
/// Use this instead of connectivity_plus when you need to know if external APIs are reachable
/// (e.g. on a hotspot with WiFi but no internet).
class NetworkAvailabilityService {
  static const Duration _timeout = Duration(seconds: 3);

  /// Returns true if the backend (and thus internet) is reachable.
  static Future<bool> hasInternet() async {
    try {
      final res = await http
          .get(Uri.parse("${ServerConfig.baseUrl}/token-values"))
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
