import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'login_screen.dart';
import 'anggota/cash_flow_page.dart';
import 'anggota/reimburse_request_page.dart';
import 'anggota/notification_page.dart';
import 'anggota/daftar_tagihan_page.dart';
// Note: error_service tidak dipanggil lagi di dalam build method untuk mencegah render error.
// import '/services/error_service.dart'; 

class AnggotaScreen extends StatefulWidget {
  const AnggotaScreen({super.key});

  @override
  State<AnggotaScreen> createState() => _AnggotaScreenState();
}

class _AnggotaScreenState extends State<AnggotaScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? "";
  String groupId = "";
  int lastRead = 0;
  
  late Stream<DocumentSnapshot> _userStream;

  @override
  void initState() {
    super.initState();
    _userStream = FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
    _initData();
  }

  Future<void> setupNotification() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // 1. Minta Izin (Khusus iOS & Android 13+)
  await messaging.requestPermission();

  // 2. Ambil Token HP ini
  String? token = await messaging.getToken();

  if (token != null) {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    // 3. Simpan ke koleksi users agar Bendahara bisa memanggilnya nanti
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'fcmToken': token,
    });
  }
}

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        lastRead = prefs.getInt('last_read_$_uid') ?? 0;
      });
    }

    var userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    if (userDoc.exists && mounted) {
      setState(() {
        groupId = userDoc['groupId'] ?? "";
      });
    }
  }

  Future<void> _updateLastRead(Timestamp timestamp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_read_$_uid', timestamp.millisecondsSinceEpoch);
    if (mounted) {
      setState(() => lastRead = timestamp.millisecondsSinceEpoch);
    }
  }

  void _openNotif(Timestamp latestTimestamp) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationPage()),
    );
    _updateLastRead(latestTimestamp);
  }

  @override
  Widget build(BuildContext context) {
    if (groupId.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1A237E))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, userSnap) {
          if (userSnap.hasError) return const Center(child: Text("Terjadi kesalahan"));
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());

          final userData = userSnap.data!.data() as Map<String, dynamic>?;
          String namaUser = userData?['name'] ?? "Anggota";

          return Stack(
            children:[
              _buildHeaderBackground(),
              SafeArea(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers:[
                    _buildAppBar(namaUser),
                    SliverToBoxAdapter(child: _buildBalanceCard()),
                    SliverToBoxAdapter(child: _buildPaymentReminder()),
                    _buildSectionTitle("Layanan Kas"),
                    _buildMenuGrid(context),
                    const SliverToBoxAdapter(child: SizedBox(height: 50)), // Jarak bawah layar
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- REFACTORING WIDGET UNTUK PERFORMA & RESPONSIVITAS ---

  Widget _buildHeaderBackground() {
    return Container(
      height: 240, // Ditinggikan sedikit agar aman di layar notch/Dynamic Island
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors:[Color(0xFF1A237E), Color(0xFF3949AB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
    );
  }

  // --- FIX APPBAR OVERFLOW ---
  Widget _buildAppBar(String namaUser) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('groups').doc(groupId).snapshots(),
          builder: (context, groupSnap) {
            String namaGrup = groupSnap.hasData && groupSnap.data!.exists
                ? groupSnap.data!['name']
                : "Anggota Grup";

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children:[
                // Dibungkus Expanded agar teks panjang tidak menabrak ikon sebelah kanan
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:[
                      Text(
                        "Halo, $namaUser", 
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        namaGrup, 
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children:[
                    _buildNotificationIcon(),
                    const SizedBox(width: 5),
                    _buildLogoutButton(),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 25, 25, 15),
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
      ),
    );
  }

  // --- FIX MENU GRID AGAR TIDAK PENYET ---
  Widget _buildMenuGrid(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200, // Otomatis atur jumlah kolom berdasarkan lebar HP
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 1.15, // Disesuaikan agar kotak lega
        ),
        delegate: SliverChildListDelegate([
          _buildMenuBox(context, "Bayar Kas", Icons.account_balance_wallet_rounded, const Color(0xFF1A237E), const DaftarTagihanPage()),
          _buildMenuBox(context, "Cash Flow", Icons.swap_vert_rounded, Colors.teal, const CashFlowPage()),
          _buildMenuBox(context, "Reimburse", Icons.request_quote_rounded, Colors.orange[800]!, const ReimburseRequestPage()),
        ]),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .where('groupId', isEqualTo: groupId)
          .orderBy('tanggal', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        bool hasNew = false;
        Timestamp latestTimestamp = Timestamp.now();
        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          var doc = snap.data!.docs.first.data() as Map<String, dynamic>;
          latestTimestamp = doc['tanggal'] ?? Timestamp.now();
          hasNew = latestTimestamp.millisecondsSinceEpoch > lastRead;
        }
        return Stack(
          children:[
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
              ),
              onPressed: () => _openNotif(latestTimestamp),
            ),
            if (hasNew)
              Positioned(
                right: -2, top: -2,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.indigo, width: 2)),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMenuBox(BuildContext context, String title, IconData icon, Color color, Widget page) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      borderRadius: BorderRadius.circular(25),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow:[BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children:[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title, 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2D3142)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis, // Cegah teks panjang overflow
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
      ),
      onPressed: _showLogoutDialog,
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout"),
        content: const Text("Yakin ingin keluar dari akun?"),
        actions:[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- FIX RENDER BUG PADA TRY CATCH & RESPONSIVITAS SALDO ---
  Widget _buildBalanceCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('transactions').where('groupId', isEqualTo: groupId).snapshots(),
      builder: (context, snap) {
        double total = 0;
        if (snap.hasData) {
          for (var d in snap.data!.docs) {
            try {
              double jumlah = (d['jumlah'] ?? 0).toDouble();
              d['type'] == 'masuk' ? total += jumlah : total -= jumlah;
            } catch (e) {
              // PENTING: Tidak boleh memanggil method dialog/snackbar selama render (build) UI.
              // Error cukup diabaikan secara diam-diam (silent fail) pada perhitungan ini.
              debugPrint("Format error on transaction: $e");
            }
          }
        }
        
        final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: const Color(0xFF282C34),
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(colors:[Color(0xFF282C34), Color(0xFF3F4451)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow:[BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:[
              const Text("SALDO KAS GRUP SAAT INI", style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.1)),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(currency.format(total), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10)
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children:[
                    Icon(Icons.verified_user_rounded, color: Colors.blueAccent, size: 16),
                    SizedBox(width: 8),
                    Text("Laporan transparan & akurat", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
  
  // --- FIX KOTAK PENGINGAT (REMINDER) ---
  Widget _buildPaymentReminder() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('kas_deadline').where('groupId', isEqualTo: groupId).snapshots(),
      builder: (context, tagihanSnap) {
        if (!tagihanSnap.hasData || tagihanSnap.data!.docs.isEmpty) return const SizedBox();
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('pembayaran').where('uid_pengirim', isEqualTo: _uid).where('status', isEqualTo: 'disetujui').snapshots(),
          builder: (context, bayarSnap) {
            if (!bayarSnap.hasData) return const SizedBox();
            List<String> bulanLunas = bayarSnap.data!.docs.map((d) => d['bulan'].toString()).toList();
            List<QueryDocumentSnapshot> tagihanBelumLunas = tagihanSnap.data!.docs.where((doc) => !bulanLunas.contains(doc['bulan'])).toList();
            
            if (tagihanBelumLunas.isEmpty) return const SizedBox();
            
            return Container(
              margin: const EdgeInsets.fromLTRB(25, 15, 25, 0),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(22), 
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                boxShadow:[BoxShadow(color: Colors.redAccent.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DaftarTagihanPage())),
                leading: const CircleAvatar(backgroundColor: Color(0xFFFFEBEE), child: Icon(Icons.priority_high_rounded, color: Colors.redAccent)),
                title: const Text("Tunggakan Iuran", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("Ada ${tagihanBelumLunas.length} bulan yang belum lunas.", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }
}