import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import '../services/auth_service.dart';
import '../utils/validators.dart';
import 'register_screen.dart';
import 'bendahara_screen.dart';
import 'anggota_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isContentVisible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _isContentVisible = true;
        });
      }
    });
  }

  // FUNGSI BARU: Menampilkan Pop-up Konfirmasi Keluar
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Keluar Aplikasi?"),
        content: const Text("Apakah Anda yakin ingin keluar dari aplikasi KOKAS?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Menutup pop-up saja
            child: const Text("BATAL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              SystemNavigator.pop(); // Menutup aplikasi total
            },
            child: Text("KELUAR", style: TextStyle(color: Colors.amber[800], fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleLogin() async {
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

          Widget destination = (role == 'bendahara') 
              ? const BendaharaScreen() 
              : const AnggotaScreen();

          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (context, anim, secondaryAnim) => destination,
              transitionsBuilder: (context, anim, secondaryAnim, child) {
                return FadeTransition(opacity: anim, child: child);
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
            (route) => false,
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Login Gagal: Email atau Password salah"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 600),
        opacity: _isContentVisible ? 1.0 : 0.0,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Text(
                  "Selamat Datang di KOKAS!",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Text(
                  "Silakan masuk untuk mengelola kas.",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),
                
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: AppValidators.validateEmail,
                ),
                const SizedBox(height: 20),
                
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: AppValidators.validatePassword,
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[800],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "MASUK",
                            style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: RichText(
                      text: TextSpan(
                        text: "Belum punya akun? ",
                        style: const TextStyle(color: Colors.black54),
                        children: [
                          TextSpan(
                            text: "Daftar Sekarang",
                            style: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // TOMBOL KELUAR DENGAN KONFIRMASI (UPDATED)
                Center(
                  child: TextButton.icon(
                    onPressed: _showExitDialog, // Memanggil fungsi pop-up di atas
                    icon: const Icon(Icons.exit_to_app, color: Colors.grey, size: 18),
                    label: const Text(
                      "Keluar Aplikasi",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}