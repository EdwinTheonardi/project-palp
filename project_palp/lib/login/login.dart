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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Login Store",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 24),
                    TextField(
                      controller: _storeCodeController,
                      decoration: InputDecoration(
                        labelText: "Store Code",
                        prefixIcon: Icon(Icons.code),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 20),
                    _isLoading
                        ? Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text("Memproses login...", style: TextStyle(color: Colors.grey)),
                            ],
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _handleLogin,
                              icon: Icon(Icons.login),
                              label: Text("Login", style: TextStyle(fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                    if (_error != null) ...[
                      SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: Colors.red)),
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
