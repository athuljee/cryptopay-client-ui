import 'package:shared_preferences/shared_preferences.dart';

class AuthService {

  static Future<void> login(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("user", username);
  }

  static Future<String?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("user");
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("user");
  }

}