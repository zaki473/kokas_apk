import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Fungsi Notifikasi (Tetap dipertahankan)
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
      backgroundColor: const Color(0xFFF4F6F8),
      body: Stack(
        children: [
          // Background Header Navy
          Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
          ),
          
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. CUSTOM APP BAR
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Dashboard", style: TextStyle(color: Colors.white70, fontSize: 14)),
                            Text("Anggota KOKAS", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          children: [
                            _buildNotificationIcon(),
                            const SizedBox(width: 10),
                            _buildLogoutButton(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. KARTU SALDO KAS GLOBAL
                SliverToBoxAdapter(child: _buildBalanceCard()),

                // 3. REMINDER PEMBAYARAN (Banner Dinamis)
                SliverToBoxAdapter(child: _buildPaymentReminder()),

                // 4. JUDUL MENU
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(25, 25, 25, 15),
                    child: Text("Layanan Anggota", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                  ),
                ),

                // 5. GRID MENU UTAMA
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 15,
                      crossAxisSpacing: 15,
                      childAspectRatio: 1.2,
                    ),
                    delegate: SliverChildListDelegate([
                      _buildMenuBox(context, "Bayar Kas", Icons.account_balance_wallet_rounded, const Color(0xFF1A237E), const DaftarTagihanPage()),
                      _buildMenuBox(context, "Cash Flow", Icons.swap_vert_rounded, Colors.teal, const CashFlowPage()),
                      _buildMenuBox(context, "Reimburse", Icons.request_quote_rounded, Colors.orange[800]!, const ReimburseRequestPage()),
                    ]),
                  ),
                ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 50)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET NOTIFIKASI DENGAN LOGIKA SHAPED PREF ---
  Widget _buildNotificationIcon() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('announcements').orderBy('tanggal', descending: true).limit(1).snapshots(),
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
                  icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                  onPressed: _openNotif,
                ),
                if (hasNewNotif)
                  Positioned(
                    right: 12, top: 12,
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // --- WIDGET SALDO KAS GLOBAL ---
  Widget _buildBalanceCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('transactions').snapshots(),
      builder: (context, snap) {
        double total = 0;
        if (snap.hasData) {
          for (var d in snap.data!.docs) {
            double jumlah = (d['jumlah'] ?? 0).toDouble();
            d['type'] == 'masuk' ? total += jumlah : total -= jumlah;
          }
        }
        final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 25),
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: const Color(0xFF282C34), // Dark Grey-Blue
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
            gradient: const LinearGradient(
              colors: [Color(0xFF282C34), Color(0xFF3F4451)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("SALDO KAS KOKAS", style: TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 1.2)),
                  Icon(Icons.account_balance_wallet_rounded, color: Colors.white.withOpacity(0.2), size: 30),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                child: Text(
                  currency.format(total),
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: Colors.blueAccent, size: 16),
                  SizedBox(width: 8),
                  Text("Dana aman & transparan", style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  // --- WIDGET REMINDER TAGIHAN (TETAP DENGAN LOGIKA ASLI) ---
  Widget _buildPaymentReminder() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('kas_deadline').snapshots(),
      builder: (context, tagihanSnap) {
        if (!tagihanSnap.hasData || tagihanSnap.data!.docs.isEmpty) return const SizedBox();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('pembayaran')
              .where('uid_pengirim', isEqualTo: _uid)
              .where('status', isEqualTo: 'disetujui')
              .snapshots(),
          builder: (context, bayarSnap) {
            if (!bayarSnap.hasData) return const SizedBox();

            List<String> bulanLunas = bayarSnap.data!.docs.map((d) => d['bulan'].toString()).toList();
            List<QueryDocumentSnapshot> tagihanBelumLunas = tagihanSnap.data!.docs.where((doc) {
              return !bulanLunas.contains(doc['bulan']);
            }).toList();

            if (tagihanBelumLunas.isEmpty) return const SizedBox();

            return Container(
              margin: const EdgeInsets.fromLTRB(25, 20, 25, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: ListTile(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DaftarTagihanPage())),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.priority_high_rounded, color: Colors.redAccent, size: 24),
                ),
                title: const Text("Ada Tagihan Kas!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("Kamu punya ${tagihanBelumLunas.length} tagihan belum lunas.", style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }

  // --- WIDGET MENU ITEM ---
  Widget _buildMenuBox(BuildContext context, String title, IconData icon, Color color, Widget page) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      borderRadius: BorderRadius.circular(25),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2D3142))),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return IconButton(
      icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
      onPressed: _showLogoutDialog,
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout"),
        content: const Text("Yakin ingin keluar akun?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              await AuthService().signOut();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}