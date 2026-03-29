import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Tambahkan ini
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/anggota_screen.dart'; // Contoh screen tujuan setelah login
import 'package:intl/date_symbol_data_local.dart';

// 1. Konstanta Warna untuk efisiensi memori dan kemudahan maintenance
class AppColors {
  static const Color navy = Color(0xFF1A237E);
  static const Color navyLight = Color(0xFF3949AB);
}

void main() async {
  // Memastikan binding engine flutter sudah siap
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Inisialisasi format tanggal Indonesia
  await initializeDateFormatting('id', null);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KOKAS',
      theme: ThemeData(
        useMaterial3: true,
        // Global Theme agar aplikasi tidak berat saat render warna manual
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.navy,
          primary: AppColors.navy,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      // Kita gunakan AuthWrapper sebagai gerbang utama
      home: const AuthWrapper(),
    );
  }
}

/// [AuthWrapper] adalah "Otak" aplikasi untuk menentukan 
/// apakah user harus ke Login atau langsung ke Dashboard
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Mendengarkan perubahan status login dari Firebase
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Jika koneksi masih loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreenContent();
        }
        
        // Jika data user ada (sudah login)
        if (snapshot.hasData) {
          // Ganti ke screen dashboard yang sesuai (misal: AnggotaScreen)
          return const AnggotaScreen(); 
        }

        // Jika tidak ada data user (belum login)
        return const SplashScreenWrapper();
      },
    );
  }
}

class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({super.key});

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Dipercepat sedikit agar UX terasa snappy
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    
    _controller.forward();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Delay 2.5 detik cukup untuk branding, jangan terlalu lama agar user tidak bosan
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    
    // Pindah ke Login dengan transisi halus
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy, 
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: const SplashScreenContent(),
      ),
    );
  }
}

/// UI Content dipisah agar bisa dipanggil oleh StreamBuilder (Clean Code)
class SplashScreenContent extends StatelessWidget {
  const SplashScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.account_balance_wallet_rounded,
          size: 100,
          color: Colors.white,
        ),
        const SizedBox(height: 20),
        const Text(
          "KOKAS",
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
        ),
        const Text(
          "Management Kas Masa Kini",
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
        const SizedBox(height: 100),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}