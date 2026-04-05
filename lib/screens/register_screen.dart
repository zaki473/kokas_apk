import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '/services/error_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isContentVisible = false;

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isContentVisible = true);
    });
  }

  void _handleRegister() async {
  if (_isLoading) return;

  FocusScope.of(context).unfocus();

  if (_formKey.currentState!.validate()) {
    setState(() => _isLoading = true);

    try {
      await AuthService().registerUser(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _namaController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // ✅ TAMPILKAN DIALOG SUKSES
      await ErrorService.showSuccess(
        context, 
        "Registrasi Berhasil! Akun kamu sudah terdaftar di sistem KOKAS. Silakan login."
      );

      // ✅ KEMBALI KE HALAMAN LOGIN
      if (mounted) Navigator.pop(context);

    // 🔥 TANGKAP ERROR KHUSUS FIREBASE DI SINI
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      String pesanError = "Terjadi kesalahan saat mendaftar.";
      
      // Deteksi jika email sudah dipakai
      if (e.code == 'email-already-in-use') {
        pesanError = "Email ini sudah terdaftar. Silakan gunakan email lain atau langsung Login.";
      } else if (e.code == 'weak-password') {
        pesanError = "Password terlalu lemah. Gunakan minimal 6 karakter.";
      } else if (e.code == 'invalid-email') {
        pesanError = "Format email tidak valid.";
      }

      // Tampilkan pesan error pakai SnackBar / Dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pesanError),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );

    // 🔥 TANGKAP ERROR LAINNYA
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Lempar ke ErrorService bawaanmu jika errornya bukan dari Firebase
      await ErrorService.show(context, e);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    // GestureDetector agar keyboard turun saat tap di luar area input
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF1A237E), // BACKGROUND FULL NAVY
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            "Buat Akun Baru",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: AnimatedOpacity(
          duration: const Duration(milliseconds: 600),
          opacity: _isContentVisible ? 1.0 : 0.0,
          child: Container(
            height: double.infinity,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A237E), Color(0xFF0D1242)], // Gradasi Navy
              ),
            ),
            // 🔥 LayoutBuilder untuk mencegah overflow
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight, // Minimal setinggi layar yang tersisa
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center, // Pusatkan konten
                            children: [
                              const SizedBox(height: 20),
                              // Icon Person Putih
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person_add_rounded,
                                  size: 70,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 30),
                              const Text(
                                "Daftar Anggota",
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                "Gabung KOKAS untuk kelola kas bersama",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 40),

                              // Input Nama
                              _buildTextField(
                                controller: _namaController,
                                label: "Nama Lengkap",
                                icon: Icons.person_outline_rounded,
                                validator: AppValidators.validateName,
                                keyboardType: TextInputType.name,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 15),

                              // Input Email
                              _buildTextField(
                                controller: _emailController,
                                label: "Alamat Email",
                                icon: Icons.email_outlined,
                                validator: AppValidators.validateEmail,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 15),

                              // Input Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleRegister(),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: "Password",
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: Colors.white70,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.white70,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.1),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.1),
                                    ),
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
                                validator: AppValidators.validatePassword,
                              ),

                              const SizedBox(height: 45),

                              // Tombol Daftar
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF1A237E),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    elevation: 5, // Sedikit shadow
                                  ),
                                  onPressed: _isLoading ? null : _handleRegister,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF1A237E),
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : const Text(
                                          "DAFTAR SEKARANG",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                ),
                              ),
                              
                              const Spacer(), // 🔥 Mendorong tombol login ke bawah

                              // Tombol Kembali / Login
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: RichText(
                                  text: const TextSpan(
                                    text: "Sudah punya akun? ",
                                    style: TextStyle(color: Colors.white70),
                                    children: [
                                      TextSpan(
                                        text: "Login di sini",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Widget Helper Textfield Navy Style
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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
      validator: validator,
    );
  }
}