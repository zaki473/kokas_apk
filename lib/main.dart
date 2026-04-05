import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart'; // ✅ WAJIB: Untuk pengecekan kIsWeb
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/anggota_screen.dart';

// 🔥 1. GLOBAL NAVIGATOR KEY (Agar bisa pindah halaman dari luar Widget Tree)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 2. Definisikan Channel Notifikasi (Hanya digunakan oleh Android)
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Channel ini digunakan untuk notifikasi penting.',
  importance: Importance.max,
  playSound: true,
);

// 3. Inisialisasi Plugin Local Notifications (Hanya untuk Mobile)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// 4. Handler BACKGROUND (Luar Class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

// 🔥 5. HANDLER KLIK NOTIFIKASI LOKAL (Saat app sedang terbuka)
void handleLocalNotifClick(NotificationResponse response) {
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (context) => const AnggotaScreen()),
  );
}

class AppColors {
  static const Color navy = Color(0xFF1A237E);
  static const Color navyLight = Color(0xFF3949AB);
  static const Color navyDark = Color(0xFF0A0F3D); // Tambahan untuk gradasi
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi Firebase sesuai platform (Web/Mobile)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Inisialisasi format tanggal Indonesia
  await initializeDateFormatting('id', null);

  // ✅ Proteksi fitur Mobile agar tidak crash di Web
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Setup Channel untuk Android (Agar muncul pop-up melayang)
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Setup opsi presentasi (Bekerja di mobile, di web menyesuaikan browser)
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // 🔥 WAJIB: Masukkan Key Navigasi di sini!
      debugShowCheckedModeBanner: false,
      title: 'KOKAS',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.navy,
          primary: AppColors.navy,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: SplashScreenContent());
        }
        if (snapshot.hasData) {
          return const AnggotaScreen(); 
        }
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
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    
    _controller.forward();
    _setupNotificationHandlers(); 
    _navigateToNext();
    _getMyDeviceToken();
  }

  // 6. Setup Handler Notifikasi (Web-Safe)
  void _setupNotificationHandlers() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    if (!kIsWeb) {
      try {
        await messaging.subscribeToTopic("semua_anggota");
        debugPrint("Berhasil subscribe ke topik semua_anggota");
      } catch (e) {
        debugPrint("Gagal subscribe topic: $e");
      }
    }

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('User menolak izin notifikasi');
      return;
    }

    if (!kIsWeb) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: handleLocalNotifClick,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: android.smallIcon,
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
          );
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (message.data['tipe'] == 'pengumuman') {
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (context) => const AnggotaScreen()),
          );
        }
      });

      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null && message.data['tipe'] == 'pengumuman') {
          Future.delayed(const Duration(milliseconds: 3000), () {
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (context) => const AnggotaScreen()),
            );
          });
        }
      });

    } else {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("Notifikasi masuk di Web: ${message.notification?.title}");
      });
    }
  }

  void _getMyDeviceToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      debugPrint("================ FCM TOKEN SAYA ================");
      debugPrint(token ?? "Token tidak ditemukan");
      debugPrint("================================================");
    } catch (e) {
      debugPrint("Error mengambil token: $e");
    }
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 2800)); // Sedikit diperlama agar animasi terlihat
    if (!mounted) return;
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
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
      body: Container(
        // ✨ Pembaruan: Premium Gradient Background
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.navyLight,
              AppColors.navy,
              AppColors.navyDark,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: const SplashScreenContent(),
        ),
      ),
    );
  }
}

class SplashScreenContent extends StatefulWidget {
  const SplashScreenContent({super.key});

  @override
  State<SplashScreenContent> createState() => _SplashScreenContentState();
}

class _SplashScreenContentState extends State<SplashScreenContent>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // 1. Animasi Detak (Pulsing) yang lebih halus
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true); 

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutBack),
    );

    // 2. Animasi Loading Bar
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ✨ Pembaruan: Logo dengan Glassmorphism & Glow
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 85,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 40),
          
          // ✨ Pembaruan: Teks KOKAS dengan efek Shadow
          const Text(
            "KOKAS",
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: 10,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "Management Kas Masa Kini",
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const SizedBox(height: 90),
          
          // ✨ Pembaruan: Custom Modern Animated Loading Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          value: _progressController.value,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                
                // Indikator teks yang posisinya bergeser sedikit sesuai progres
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    int percent = (_progressController.value * 100).toInt();
                    return Text(
                      "Mempersiapkan data... $percent%",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}