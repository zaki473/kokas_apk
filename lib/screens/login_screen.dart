import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart'; // Import validator tadi
import 'register_screen.dart';
import 'bendahara_screen.dart';
import 'anggota_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>(); // Kunci untuk validasi form
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true; // Status sembunyi password

  void _handleLogin() async {
    // Jalankan validasi
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final userData = await AuthService().loginUser(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (userData != null) {
          String role = userData['role'];
          if (!mounted) return;

          if (role == 'bendahara') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BendaharaScreen()));
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AnggotaScreen()));
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Login Gagal: Email atau Password salah"),
          backgroundColor: Colors.red,
        ));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey, // Pasang kunci form
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: AppValidators.validateEmail, // Panggil validator
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword, // Sembunyikan jika true
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  // TOMBOL MATA
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: AppValidators.validatePassword,
              ),
              const SizedBox(height: 25),
              
              // LOGIC LOADING
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin, // Matikan tombol jika loading
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("MASUK", style: TextStyle(fontSize: 16)),
                ),
              ),
              
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: const Text("Belum punya akun? Daftar Sekarang"),
              )
            ],
          ),
        ),
      ),
    );
  }
}