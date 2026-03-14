/// Stub for web (no dart:io). Hotspot listener is only used on mobile/desktop.

class HotspotListenerService {
  static void Function()? onMerchantConnected;
  static bool get merchantConnected => false;

  static Future<bool> start() async => false;

  static void stop() {}

  static void clearMerchantConnected() {}
}
