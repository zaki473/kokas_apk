import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

// Import menu Anda
import 'bendahara/rekap_page.dart';
import 'bendahara/kas_setting_page.dart';
import 'bendahara/pengumuman_page.dart';
import 'bendahara/reimburse_page.dart';
import 'bendahara/tambah_transaksi_page.dart';
import 'bendahara/verifikasi_bayar_page.dart';
import 'bendahara/StatusAnggotaPage.dart';

class BendaharaScreen extends StatelessWidget {
  const BendaharaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F9), // Warna dasar abu kebiruan (Modern)
      body: Stack(
        children: [
          // 1. BACKGROUND DECORATION (Lingkaran gradasi agar tidak flat)
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
              radius: 130,
              backgroundColor: Colors.amber[700]!.withOpacity(0.4),
            ),
          ),
          
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 2. CUSTOM TOP BAR (Greeting & Profile)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(25.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Halo, Bendahara", 
                              style: TextStyle(color: Colors.black54, fontSize: 16)),
                            Text("Kelola Kas KOKAS", 
                              style: TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => _showLogoutDialog(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                            ),
                            child: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                          ),
                        )
                      ],
                    ),
                  ),
                ),

                // 3. KARTU SALDO UTAMA (TIDAK FLAT)
                SliverToBoxAdapter(child: _buildBalanceCard()),

                // 4. JUDUL MENU
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                    child: Text("Menu Utama", 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                ),

                // 5. GRID MENU MODERN
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildListDelegate([
                      _buildMenuItem(context, "Input Transaksi", Icons.add_box_rounded, Colors.orange, const TambahTransaksiPage()),
                      _buildMenuItem(context, "Verifikasi", Icons.verified_user_rounded, Colors.teal, const VerifikasiBayarPage()),
                      _buildMenuItem(context, "Rekap Kas", Icons.insert_chart_rounded, Colors.blueAccent, const RekapPage()),
                      _buildMenuItem(context, "Atur Kas", Icons.settings_suggest_rounded, Colors.deepPurple, const KasSettingPage()),
                      _buildMenuItem(context, "Broadcast", Icons.campaign_rounded, Colors.pinkAccent, const PengumumanPage()),
                      _buildMenuItem(context, "Reimburse", Icons.wallet_rounded, Colors.green, const ReimbursePage()),
                      _buildMenuItem(context, "Anggota", Icons.groups_3_rounded, Colors.blueGrey, const StatusAnggotaPage()),
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

  // WIDGET KARTU SALDO (PREMIUM LOOK)
  Widget _buildBalanceCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('transactions').snapshots(),
      builder: (context, snapshot) {
        double total = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            double jumlah = (doc['jumlah'] ?? 0).toDouble();
            doc['type'] == 'masuk' ? total += jumlah : total -= jumlah;
          }
        }
        final formatCurrency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [Color(0xFF212121), Color(0xFF424242)], // Dark Slate
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber[800]!.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Stack(
            children: [
              // Variasi background kartu agar tidak flat
              Positioned(
                bottom: -20,
                right: -20,
                child: Icon(Icons.account_balance_wallet, size: 150, color: Colors.white.withOpacity(0.05)),
              ),
              Padding(
                padding: const EdgeInsets.all(25.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Total Saldo KOKAS", style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 10),
                    FittedBox(
                      child: Text(
                        formatCurrency.format(total),
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        const Icon(Icons.arrow_upward, color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 5),
                        Text("Real-time Database", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // WIDGET ITEM MENU (TIDAK FLAT - EFEK FLOAT)
  Widget _buildMenuItem(BuildContext context, String title, IconData icon, Color color, Widget page) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 35),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout"),
        content: const Text("Apakah Anda yakin ingin keluar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              await AuthService().signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            }, 
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}