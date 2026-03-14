import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inisialisasi Firebase & Date di sini sudah benar
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('id', null); 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Kita gunakan FutureBuilder untuk mengecek apakah aplikasi sudah siap atau belum
      home: const SplashScreenWrapper(), 
    );
  }
}

// Widget tambahan untuk menangani Loading sebelum masuk ke Login
class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({super.key});

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async { 
  await Future.delayed(const Duration(seconds: 2));
  
  if (!mounted) return;
  
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const LoginScreen()),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Warna background disamakan dengan tema Bendahara (Amber)
      backgroundColor: Colors.amber[700],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bisa diganti Ikon atau Image.asset logo kamu
            const Icon(Icons.account_balance_wallet, size: 80, color: Colors.white),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            const Text(
              "KOKAS",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}