import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Tambahkan ini
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'anggota/cash_flow_page.dart';
import 'anggota/reimburse_request_page.dart';
import 'anggota/notification_page.dart';
import 'anggota/DaftarTagihanPage.dart';

class AnggotaScreen extends StatefulWidget {
  const AnggotaScreen({super.key});

  @override
  State<AnggotaScreen> createState() => _AnggotaScreenState();
}

class _AnggotaScreenState extends State<AnggotaScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? "";

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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Dashboard Anggota", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue[700],
        iconTheme: const IconThemeData(color: Colors.white),
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
                  bool hasNewNotif = false;
                  if (snap.hasData && snap.data!.docs.isNotEmpty && pref.hasData) {
                    int lastAnnounce = (snap.data!.docs.first['tanggal'] as Timestamp).millisecondsSinceEpoch;
                    int lastRead = pref.data!.getInt('last_read') ?? 0;
                    if (lastAnnounce > lastRead) hasNewNotif = true;
                  }
                  return Stack(
                    children: [
                      IconButton(icon: const Icon(Icons.notifications), onPressed: _openNotif),
                      if (hasNewNotif)
                        Positioned(
                          right: 12, top: 12,
                          child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                        ),
                    ],
                  );
                },
              );
            },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _showLogoutDialog()),
        ],
      ),
      body: Column(
        children: [
          _buildBalanceCard(),    
          
          // REMINDER BAYAR KAS (Diletakkan di atas menu)
          _buildPaymentReminder(), 

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
                _box(context, "Bayar Kas", Icons.account_balance_wallet, Colors.orange, const DaftarTagihanPage()),
                _box(context, "Ajukan Reimburse", Icons.request_quote, Colors.green, const ReimburseRequestPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET REMINDER PEMBAYARAN KAS ---
  Widget _buildPaymentReminder() {
    return StreamBuilder<QuerySnapshot>(
      // Mengambil semua daftar tagihan
      stream: FirebaseFirestore.instance.collection('kas_deadline').snapshots(),
      builder: (context, tagihanSnap) {
        if (!tagihanSnap.hasData || tagihanSnap.data!.docs.isEmpty) return const SizedBox();

        return StreamBuilder<QuerySnapshot>(
          // Mengambil data pembayaran user ini yang sudah disetujui
          stream: FirebaseFirestore.instance
              .collection('pembayaran')
              .where('uid_pengirim', isEqualTo: _uid)
              .where('status', isEqualTo: 'disetujui')
              .snapshots(),
          builder: (context, bayarSnap) {
            if (!bayarSnap.hasData) return const SizedBox();

            // Mendapatkan daftar bulan yang sudah dibayar (Lunas)
            List<String> bulanLunas = bayarSnap.data!.docs.map((d) => d['bulan'].toString()).toList();

            // Memfilter tagihan mana saja yang belum ada di daftar lunas
            List<QueryDocumentSnapshot> tagihanBelumLunas = tagihanSnap.data!.docs.where((doc) {
              return !bulanLunas.contains(doc['bulan']);
            }).toList();

            // Jika semua tagihan sudah lunas, banner tidak muncul
            if (tagihanBelumLunas.isEmpty) return const SizedBox();

            return Container(
              margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.orange.shade700]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DaftarTagihanPage())),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.priority_high, color: Colors.white),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "PENTING: Tagihan Kas Menunggu",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            "Kamu punya ${tagihanBelumLunas.length} tagihan yang belum lunas. Klik untuk bayar sekarang!",
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

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
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}