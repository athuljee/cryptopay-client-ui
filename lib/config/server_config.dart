class ServerConfig {
  // Existing online backend (unchanged flow).
  static const String onlineBaseUrl =
      "https://cryptopay-blockchain.onrender.com";

  // Backward-compatible alias used by existing online code.
  static const String baseUrl = onlineBaseUrl;

  // Local offline server endpoint target (client -> merchant machine).
  // Change localOfflineHost when merchant uses a different LAN IP.
  // Leave empty to enable automatic local merchant discovery on WLAN/hotspot.
  static String localOfflineHost = "";
  static const int localOfflinePort = 3001;
  static String get localOfflineBaseUrl =>
      "http://$localOfflineHost:$localOfflinePort";
}