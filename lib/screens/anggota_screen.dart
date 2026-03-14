import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import 'anggota/cash_flow_page.dart';
import 'anggota/reimburse_request_page.dart';
import 'anggota/notification_page.dart';

class AnggotaScreen extends StatefulWidget {
  const AnggotaScreen({super.key});
  @override
  State<AnggotaScreen> createState() => _AnggotaScreenState();
}

class _AnggotaScreenState extends State<AnggotaScreen> {
  void _openNotif() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('last_read', DateTime.now().millisecondsSinceEpoch);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationPage()),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Anggota"),
        backgroundColor: Colors.blue[700],
        actions: [
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
                  bool red = false;
                  if (snap.hasData &&
                      snap.data!.docs.isNotEmpty &&
                      pref.hasData) {
                    int lastA = (snap.data!.docs.first['tanggal'] as Timestamp)
                        .millisecondsSinceEpoch;
                    int lastR = pref.data!.getInt('last_read') ?? 0;
                    if (lastA > lastR) red = true;
                  }
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications),
                        onPressed: _openNotif,
                      ),
                      if (red)
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Logout"),
                    content: const Text(
                      "Apakah kamu yakin ingin keluar dari akun?",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // tutup popup
                        },
                        child: const Text("Batal"),
                      ),

                      ElevatedButton(
                        onPressed: () async {
                          // Tambah async
                          await AuthService().signOut(); // Ganti jadi await

                          if (!context.mounted) return; // Cek mounted

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text("Logout"),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBalance(), // Gunakan logika StreamBuilder Total Kas yang sama dengan bendahara, hanya beda warna biru
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(20),
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              children: [
                _box(
                  context,
                  "Cash Flow",
                  Icons.swap_vert,
                  Colors.blue,
                  const CashFlowPage(),
                ),
                _box(
                  context,
                  "Ajukan Reimburse",
                  Icons.request_quote,
                  Colors.green,
                  const ReimburseRequestPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildBalance & _box sama seperti bendahara namun warna disesuaikan (biru)
  // --- ISI DARI WIDGET SALDO (BIRU) ---
  Widget _buildBalance() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('transactions').snapshots(),
      builder: (context, snap) {
        int total = 0;
        if (snap.hasData) {
          for (var d in snap.data!.docs) {
            // Logika: Jika masuk ditambah, jika keluar dikurang
            if (d['type'] == 'masuk') {
              total += (d['jumlah'] as int);
            } else {
              total -= (d['jumlah'] as int);
            }
          }
        }

        // Format mata uang Rupiah
        final currency = NumberFormat.currency(
          locale: 'id',
          symbol: 'Rp ',
          decimalDigits: 0,
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.blue[700],
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Saldo Kas Saat Ini",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                currency.format(total),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- ISI DARI WIDGET MENU KOTAK ---
  Widget _box(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget page,
  ) {
    return InkWell(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              radius: 30,
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
