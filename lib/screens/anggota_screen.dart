import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'anggota/cash_flow_page.dart';
import 'anggota/reimburse_request_page.dart';
import 'anggota/notification_page.dart';
import 'anggota/bayar_kas_page.dart'; // Pastikan file ini sudah dibuat

class AnggotaScreen extends StatefulWidget {
  const AnggotaScreen({super.key});

  @override
  State<AnggotaScreen> createState() => _AnggotaScreenState();
}

class _AnggotaScreenState extends State<AnggotaScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Timer untuk mengupdate detik real-time agar countdown berjalan lancar
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Fungsi untuk membuka notifikasi dan mereset tanda merah
  void _openNotif() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('last_read', DateTime.now().millisecondsSinceEpoch);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationPage()),
    ).then((_) => setState(() {})); // Refresh UI saat kembali agar titik merah hilang
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Dashboard Anggota", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[700],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // LONCENG NOTIFIKASI DENGAN TITIK MERAH
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .orderBy('tanggal', descending: true)
                .limit(1)
                .snapshots(),
            builder: (context, snap) {
              return FutureBuilder<SharedPreferences>(
                future: SharedPreferences.getInstance(),
                builder: (context, pref) {
                  bool hasNewNotif = false;
                  if (snap.hasData && snap.data!.docs.isNotEmpty && pref.hasData) {
                    int lastAnnounce = (snap.data!.docs.first['tanggal'] as Timestamp).millisecondsSinceEpoch;
                    int lastRead = pref.data!.getInt('last_read') ?? 0;
                    if (lastAnnounce > lastRead) hasNewNotif = true;
                  }
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications),
                        onPressed: _openNotif,
                      ),
                      if (hasNewNotif)
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
          // TOMBOL LOGOUT DENGAN KONFIRMASI
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBalanceCard(),    // Kartu Saldo Biru
          _buildDeadlineBanner(), // Banner Countdown yang bisa hilang otomatis
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Menu Utama", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              children: [
                _box(context, "Cash Flow", Icons.swap_vert, Colors.blue, const CashFlowPage()),
                _box(context, "Bayar Kas", Icons.account_balance_wallet, Colors.orange, const BayarKasPage()),
                _box(context, "Ajukan Reimburse", Icons.request_quote, Colors.green, const ReimburseRequestPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET SALDO KAS REAL-TIME
  Widget _buildBalanceCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('transactions').snapshots(),
      builder: (context, snap) {
        int total = 0;
        if (snap.hasData) {
          for (var d in snap.data!.docs) {
            d['type'] == 'masuk' ? total += (d['jumlah'] as int) : total -= (d['jumlah'] as int);
          }
        }
        final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.blue[700],
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Saldo Kas Saat Ini", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text(
                currency.format(total),
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  // WIDGET BANNER COUNTDOWN (Hanya muncul jika belum expired)
  Widget _buildDeadlineBanner() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('settings').doc('kas_deadline').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
        
        var data = snapshot.data!.data() as Map<String, dynamic>;
        DateTime deadline = (data['tanggal'] as Timestamp).toDate();

        // Jika waktu sudah lewat, banner hilang otomatis secara real-time
        if (_now.isAfter(deadline)) return const SizedBox();

        Duration sisa = deadline.difference(_now);
        String countdownText = "${sisa.inDays}h ${sisa.inHours % 24}j ${sisa.inMinutes % 60}m ${sisa.inSeconds % 60}d";

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Batas Terakhir Bayar Kas:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(countdownText, style: const TextStyle(fontSize: 16, color: Colors.orange, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // WIDGET KOTAK MENU
  Widget _box(BuildContext context, String title, IconData icon, Color color, Widget page) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 30,
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // FUNGSI LOGOUT
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Yakin ingin keluar akun?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              await AuthService().signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}