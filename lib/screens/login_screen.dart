import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import 'register_screen.dart';
import 'bendahara_screen.dart';
import 'anggota_screen.dart';
import 'package:kokas/screens/setup_group_page.dart';
import '/services/error_service.dart';

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
    // Animasi muncul lebih rapi
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _isContentVisible = true);
    });
  }

  @override
  void dispose() {
    // WAJIB: Mencegah Memory Leak agar HP tidak panas/lemot
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Keluar Aplikasi?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("Apakah Anda yakin ingin menutup aplikasi KOKAS?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("BATAL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => SystemNavigator.pop(),
            child: const Text("KELUAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleLogin() async {
    if (_isLoading) return; // 🔥 anti double click

    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final userData = await AuthService().loginUser(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (!mounted) return;

        if (userData != null) {
          String role = (userData['role'] ?? 'none').toString();
          String groupId = (userData['groupId'] ?? '').toString();

          Widget destination;
          if (role == 'none' || groupId.isEmpty) {
            destination = const SetupGroupPage();
          } else if (role == 'bendahara') {
            destination = const BendaharaScreen();
          } else {
            destination = const AnggotaScreen();
          }

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => destination),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Data user tidak ditemukan")),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ErrorService.show(context, e);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // GestureDetector agar jika user klik di luar input, keyboard langsung menutup
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: PopScope(
        canPop: false, // Mencegah back button langsung keluar
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _showExitDialog(); // Tampilkan dialog konfirmasi jika tekan back
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF1A237E),
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
                  colors: [Color(0xFF1A237E), Color(0xFF0D1242)],
                ),
              ),
              child: SafeArea(
                child: Center(
                  // Agar konten tetap di tengah jika layar besar
                  child: SingleChildScrollView(
                    physics:
                        const BouncingScrollPhysics(), // Scroll lebih smooth di iOS/Android
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 80,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "KOKAS LOGIN",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          const Text(
                            "Kelola kas organisasi dengan aman",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 50),

                          _buildTextField(
                            controller: _emailController,
                            label: "Alamat Email",
                            icon: Icons.email_outlined,
                            validator: AppValidators.validateEmail,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 20),

                          _buildTextField(
                            controller: _passwordController,
                            label: "Password",
                            icon: Icons.lock_outline,
                            isPassword: true,
                            obscureText: _obscurePassword,
                            toggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            validator: AppValidators.validatePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                          ),
                          const SizedBox(height: 40),

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
                                elevation:
                                    5, // Sedikit shadow agar lebih timbul
                              ),
                              onPressed: _isLoading ? null : _handleLogin,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : const Text(
                                      "MASUK SEKARANG",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 25),

                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            ),
                            child: RichText(
                              text: const TextSpan(
                                text: "Belum punya akun? ",
                                style: TextStyle(color: Colors.white70),
                                children: [
                                  TextSpan(
                                    text: "Daftar Disini",
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
                          const SizedBox(height: 40),

                          TextButton.icon(
                            onPressed: _showExitDialog,
                            icon: const Icon(
                              Icons.power_settings_new_rounded,
                              color: Colors.white54,
                              size: 20,
                            ),
                            label: const Text(
                              "Keluar Aplikasi",
                              style: TextStyle(color: Colors.white54),
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
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? toggleObscure,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
                onPressed: toggleObscure,
              )
            : null,
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
    );
  }
}
