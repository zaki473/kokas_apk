import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'bendahara/rekap_page.dart';
import 'bendahara/kas_setting_page.dart';
import 'bendahara/pengumuman_page.dart';
import 'bendahara/reimburse_page.dart';
import 'bendahara/tambah_transaksi_page.dart';
import 'bendahara/verifikasi_bayar_page.dart';
import 'bendahara/status_anggota_page.dart';

class BendaharaScreen extends StatefulWidget {
  const BendaharaScreen({super.key});

  @override
  State<BendaharaScreen> createState() => _BendaharaScreenState();
}

class _BendaharaScreenState extends State<BendaharaScreen> {
  final String myUid = FirebaseAuth.instance.currentUser!.uid;
  late Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    _userStream = FirebaseFirestore.instance.collection('users').doc(myUid).snapshots();
  }

  String formatCurrency(double value) =>
      NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);

  String formatCompact(double value) =>
      NumberFormat.compactCurrency(locale: 'id', symbol: 'Rp ').format(value);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userStream,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final String namaBendahara = userData?['name'] ?? "Bendahara";
        final String? groupId = userData?['groupId'];

        if (groupId == null || groupId.isEmpty) {
          return _buildNoGroupUI();
        }

        return _buildMainDashboard(namaBendahara, groupId);
      },
    );
  }

  Widget _buildMainDashboard(String namaBendahara, String groupId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('groups').doc(groupId).snapshots(),
      builder: (context, groupSnapshot) {
        final groupData = groupSnapshot.data?.data() as Map<String, dynamic>?;
        final String namaGrup = groupData?['name'] ?? "Grup Kas";

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('transactions')
              .where('groupId', isEqualTo: groupId)
              .snapshots(),
          builder: (context, transSnapshot) {
            double totalIn = 0;
            double totalOut = 0;

            if (transSnapshot.hasData) {
              for (var doc in transSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                double jumlah = (data['jumlah'] ?? 0).toDouble();
                data['type'] == 'masuk' ? totalIn += jumlah : totalOut += jumlah;
              }
            }
            double balance = totalIn - totalOut;

            return Scaffold(
              backgroundColor: const Color(0xFFF4F6F8),
              body: Stack(
                children: [
                  _buildHeaderBg(),
                  SafeArea(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        _buildAppBar(namaBendahara, namaGrup),
                        SliverToBoxAdapter(child: _buildBalanceCard(context, balance, groupId)),
                        SliverToBoxAdapter(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                          child: _buildQuickMenu(context),
                        )),
                        _buildSectionLabel("Statistik Kas"),
                        SliverToBoxAdapter(child: _buildMiniStats(totalIn, totalOut)),
                        _buildSectionLabel("Menu Lainnya"),
                        _buildOtherMenuGrid(context),
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
  }

  Widget _buildHeaderBg() {
    return Container(
      height: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
      ),
    );
  }

  Widget _buildAppBar(String nama, String grup) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Halo Bendahara, $nama", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                Text(grup, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 20, 25, 12), // Jarak antar section ditambah
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
      ),
    );
  }

  // --- FIX GRID PENYET ---
  Widget _buildOtherMenuGrid(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 1.2, // Rasio diubah dari 1.5 ke 1.2 agar kotak lebih tinggi
        ),
        delegate: SliverChildListDelegate([
          _buildWideMenuItem(context, "Atur Kas", Icons.settings_rounded, Colors.indigo, const KasSettingPage()),
          _buildWideMenuItem(context, "Broadcast", Icons.campaign_rounded, Colors.orange, const PengumumanPage()),
          _buildWideMenuItem(context, "Anggota", Icons.people_alt_rounded, Colors.blueGrey, const StatusAnggotaPage()),
        ]),
      ),
    );
  }

  // --- FIX STATISTIK KAS ---
  Widget _buildMiniStats(double incoming, double outgoing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Row(
        children: [
          Expanded(child: _itemStat("Masuk", formatCompact(incoming), Icons.arrow_downward, Colors.green)),
          const SizedBox(width: 15), // Jarak antar kotak statistik ditambah
          Expanded(child: _itemStat("Keluar", formatCompact(outgoing), Icons.arrow_upward, Colors.red)),
        ],
      ),
    );
  }

  Widget _itemStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16), // Padding ditambah dari 12 ke 16 agar tidak penyet
      decoration: BoxDecoration(
        color: Colors.white, // Background putih agar lebih clean
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column( // Diubah ke Column agar susunan lebih vertikal/lega
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildWideMenuItem(BuildContext context, String title, IconData icon, Color color, Widget page) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column( // Diubah ke Column agar lebih proporsional di grid
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 30),
                const SizedBox(height: 10),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, double balance, String code) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFF282C34),
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF282C34), Color(0xFF3E4451)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SALDO KAS SAAT INI", style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(formatCurrency(balance), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 25),
          _buildCodeBadge(context, code),
        ],
      ),
    );
  }

  Widget _buildCodeBadge(BuildContext context, String code) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("KODE GRUP", style: TextStyle(color: Colors.white38, fontSize: 9)),
              Text(code, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kode disalin!"), behavior: SnackBarBehavior.floating));
            },
            icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
          )
        ],
      ),
    );
  }

  Widget _buildQuickMenu(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15)],
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
    );
  }

  Widget _buildQuickAction(BuildContext context, String label, IconData icon, Color color, Widget page) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildNoGroupUI() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_off_rounded, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("Anda belum memiliki grup kas aktif"),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/setupGroup'),
              child: const Text("Buat / Gabung Grup"),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () => AuthService().signOut(), child: const Text("Logout")),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await AuthService().signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}