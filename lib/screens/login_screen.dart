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
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _isContentVisible = true;
        });
      }
    });
  }

  // FUNGSI: Pop-up Konfirmasi Keluar (Tema Navy)
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Keluar Aplikasi?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Apakah Anda yakin ingin menutup aplikasi KOKAS?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("BATAL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => SystemNavigator.pop(),
            child: const Text("KELUAR", style: TextStyle(color: Colors.white)),
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
              transitionDuration: const Duration(milliseconds: 800),
            ),
            (route) => false,
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Login Gagal: Email atau Password salah"),
            backgroundColor: Colors.redAccent,
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
      backgroundColor: const Color(0xFF1A237E), // BACKGROUND FULL NAVY
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 800),
        opacity: _isContentVisible ? 1.0 : 0.0,
        child: Container(
          height: double.infinity,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A237E), Color(0xFF0D1242)], // Gradasi Navy Gelap
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    // Logo/Icon Putih
                    const Icon(Icons.account_balance_wallet_rounded, size: 80, color: Colors.white),
                    const SizedBox(height: 20),
                    const Text(
                      "KOKAS LOGIN",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
                    ),
                    const Text(
                      "Kelola kas organisasi dengan aman",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 50),
                    
                    // INPUT EMAIL (MODERN WHITE STYLE)
                    _buildTextField(
                      controller: _emailController,
                      label: "Alamat Email",
                      icon: Icons.email_outlined,
                      validator: AppValidators.validateEmail,
                    ),
                    const SizedBox(height: 20),
                    
                    // INPUT PASSWORD
                    _buildTextField(
                      controller: _passwordController,
                      label: "Password",
                      icon: Icons.lock_outline,
                      isPassword: true,
                      obscureText: _obscurePassword,
                      toggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
                      validator: AppValidators.validatePassword,
                    ),
                    const SizedBox(height: 40),

                    // TOMBOL MASUK (KONTRASTERANG - PUTIH)
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1A237E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(color: Color(0xFF1A237E), strokeWidth: 3),
                              )
                            : const Text(
                                "MASUK SEKARANG",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 25),
                    
                    // DAFTAR AKUN
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
                      child: RichText(
                        text: const TextSpan(
                          text: "Belum punya akun? ",
                          style: TextStyle(color: Colors.white70),
                          children: [
                            TextSpan(
                              text: "Daftar Disini",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // TOMBOL KELUAR
                    TextButton.icon(
                      onPressed: _showExitDialog,
                      icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white54, size: 20),
                      label: const Text(
                        "Keluar Aplikasi",
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // WIDGET HELPER UNTUK TEXTFIELD NAVY STYLE
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? toggleObscure,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: isPassword 
            ? IconButton(
                icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                onPressed: toggleObscure,
              ) 
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}