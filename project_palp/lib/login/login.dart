import 'package:flutter/material.dart';
import '../services/store_service.dart';
import '../main.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _storeCodeController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  static const Color midnightBlue = Color(0xFF003366);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color cleanWhite = Colors.white;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    String storeCode = _storeCodeController.text.trim();

    try {
      await StoreService.initStore(storeCode);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NavigationHomePage()),
      );
    } catch (e) {
      setState(() {
        _error = "❌ Store tidak valid atau gagal login.";
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8,
              color: cleanWhite,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Login Store",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: midnightBlue,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _storeCodeController,
                      decoration: InputDecoration(
                        labelText: "Store Code",
                        prefixIcon: const Icon(Icons.storefront_outlined, color: midnightBlue),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? Column(
                            children: [
                              const CircularProgressIndicator(color: accentOrange),
                              const SizedBox(height: 8),
                              Text("Memproses login...", style: TextStyle(color: Colors.grey[600])),
                            ],
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _handleLogin,
                              icon: const Icon(Icons.login),
                              label: const Text("Login", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentOrange,
                                foregroundColor: cleanWhite,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}