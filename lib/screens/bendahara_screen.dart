import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // Untuk fitur Copy Kode
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

  // Fungsi pembantu untuk format mata uang
  String formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  // Fungsi pembantu untuk format singkat (jt/rb)
  String formatCompact(double value) {
    return NumberFormat.compactCurrency(locale: 'id', symbol: 'Rp ').format(value);
  }

  @override
  Widget build(BuildContext context) {
    final String myUid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      // 1. Ambil Data User (untuk tahu Nama & GroupID)
      stream: FirebaseFirestore.instance.collection('users').doc(myUid).snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        var userData = userSnapshot.data!;
        String namaBendahara = userData['name'] ?? "Bendahara";
        String groupId = userData['groupId'] ?? "";

        return StreamBuilder<DocumentSnapshot>(
          // 2. Ambil Data Grup (untuk tahu Nama Grup)
          stream: FirebaseFirestore.instance.collection('groups').doc(groupId).snapshots(),
          builder: (context, groupSnapshot) {
            String namaGrup = "Grup Kas";
            if (groupSnapshot.hasData && groupSnapshot.data!.exists) {
              namaGrup = groupSnapshot.data!['name'] ?? "Grup Kas";
            }

            return StreamBuilder<QuerySnapshot>(
              // 3. Ambil Transaksi (Hanya yang milik grup ini)
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .where('groupId', isEqualTo: groupId) // Filter berdasarkan grup
                  .snapshots(),
              builder: (context, transSnapshot) {
                double totalIn = 0;
                double totalOut = 0;
                double balance = 0;

                if (transSnapshot.hasData) {
                  for (var doc in transSnapshot.data!.docs) {
                    double jumlah = (doc['jumlah'] ?? 0).toDouble();
                    if (doc['type'] == 'masuk') {
                      totalIn += jumlah;
                    } else {
                      totalOut += jumlah;
                    }
                  }
                  balance = totalIn - totalOut;
                }

                return Scaffold(
                  backgroundColor: const Color(0xFFF4F6F8),
                  body: Stack(
                    children: [
                      // Header Background
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
                            // 1. APP BAR
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Halo Bendahara, $namaBendahara",
                                            style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                        Text(namaGrup,
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    _buildLogoutButton(context),
                                  ],
                                ),
                              ),
                            ),

                            // 2. KARTU SALDO & KODE GRUP
                            SliverToBoxAdapter(child: _buildBalanceCard(context, balance, groupId)),

                            // 3. 4 MENU UTAMA
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5))
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildQuickAction(context, "Input", Icons.add_box_rounded, Colors.blue, const TambahTransaksiPage()),
                                      _buildQuickAction(context, "Verif", Icons.verified_user_rounded, Colors.teal, const VerifikasiBayarPage()),
                                      _buildQuickAction(context, "Rekap", Icons.analytics_rounded, Colors.orange, const RekapPage()),
                                      _buildQuickAction(context, "Reimburse", Icons.account_balance_wallet_rounded, Colors.redAccent, const ReimbursePage()),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // 4. STATISTIK KAS
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(25, 20, 25, 10),
                                child: Text("Statistik Kas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            SliverToBoxAdapter(child: _buildMiniStats(totalIn, totalOut)),

                            // 5. MENU LAINNYA
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(25, 25, 25, 15),
                                child: Text("Menu Lainnya", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            ),

                            // 6. MENU GRID
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 25),
                              sliver: SliverGrid(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 15,
                                  crossAxisSpacing: 15,
                                  childAspectRatio: 1.5,
                                ),
                                delegate: SliverChildListDelegate([
                                  _buildWideMenuItem(context, "Atur Kas", Icons.settings_rounded, Colors.indigo, const KasSettingPage()),
                                  _buildWideMenuItem(context, "Broadcast", Icons.campaign_rounded, Colors.orange, const PengumumanPage()),
                                  _buildWideMenuItem(context, "Anggota", Icons.people_alt_rounded, Colors.blueGrey, const StatusAnggotaPage()),
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
              },
            );
          },
        );
      },
    );
  }

  // --- WIDGET COMPONENTS ---

  Widget _buildBalanceCard(BuildContext context, double balance, String code) {
    return Container(
      margin: const EdgeInsets.all(25),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFF282C34),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
        gradient: const LinearGradient(
          colors: [Color(0xFF282C34), Color(0xFF3E4451)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SALDO KAS SAAT INI", style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.2)),
          const SizedBox(height: 5),
          FittedBox(
            child: Text(
              formatCurrency(balance),
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("KODE GRUP UNTUK ANGGOTA", style: TextStyle(color: Colors.white38, fontSize: 10)),
                    const SizedBox(height: 4),
                    Text(code, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Kode Grup berhasil disalin!")),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.copy_all_rounded, color: Colors.white, size: 20),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMiniStats(double incoming, double outgoing) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        children: [
          Expanded(child: _itemStat("Masuk", formatCompact(incoming), Icons.arrow_downward, Colors.green)),
          const SizedBox(width: 15),
          Expanded(child: _itemStat("Keluar", formatCompact(outgoing), Icons.arrow_upward, Colors.red)),
        ],
      ),
    );
  }

  Widget _itemStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[700])),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String label, IconData icon, Color color, Widget page) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildWideMenuItem(BuildContext context, String title, IconData icon, Color color, Widget page) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return IconButton(
      onPressed: () => _showLogoutDialog(context),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout"),
        content: const Text("Yakin ingin keluar dari sistem?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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