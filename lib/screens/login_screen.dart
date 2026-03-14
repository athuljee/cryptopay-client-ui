import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/server_config.dart';
import 'signup_screen.dart';
import '../services/blockchain_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  Future<void> login() async {

    setState(() => loading = true);

    final response = await http.post(
      Uri.parse("${ServerConfig.baseUrl}/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": usernameController.text,
        "password": passwordController.text
      }),
    );

    final data = jsonDecode(response.body);

    setState(() => loading = false);

    if (data["success"] && data["role"] == "client") {
      BlockchainService.clientAddress = usernameController.text;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("user", usernameController.text);
      await prefs.setString("role", "client");

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/home');
    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid client login")),
      );

    }

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Client Login")),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),

              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),

                child: Padding(
                  padding: const EdgeInsets.all(24),

                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      const SizedBox(height: 40),

                      const Icon(
                        Icons.account_balance_wallet,
                        size: 80,
                        color: Colors.teal,
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        "Client Login",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 30),

                      TextField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: "Username",
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Password",
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(

                          onPressed: loading ? null : login,

                          child: loading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Login"),

                        ),
                      ),

                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignupScreen(role: "client"),
                            ),
                          );
                        },
                        child: const Text("Create new account"),
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}