import 'dart:io';

import 'package:flutter/foundation.dart';

/// IO implementation: listens on a local port so the merchant app can ping when connected to this device's hotspot.
class HotspotListenerService {
  static HttpServer? _server;
  static const int port = 8766;

  static void Function()? onMerchantConnected;
  static bool _merchantConnected = false;
  static bool get merchantConnected => _merchantConnected;

  static Future<bool> start() async {
    if (_server != null) return true;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server!.listen(_handleRequest);
      _merchantConnected = false;
      return true;
    } on SocketException catch (e) {
      debugPrint("HotspotListenerService: $e");
      return false;
    }
  }

  static void _handleRequest(HttpRequest request) {
    if (request.uri.path == "/ping" || request.uri.path == "/ping/") {
      _merchantConnected = true;
      onMerchantConnected?.call();
      request.response
        ..statusCode = HttpStatus.ok
        ..write("ok")
        ..close();
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
    }
  }

  static void stop() {
    _server?.close();
    _server = null;
    _merchantConnected = false;
  }

  static void clearMerchantConnected() {
    _merchantConnected = false;
  }
}
