import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

// Import semua halaman menu bendahara
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Dashboard Bendahara", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.amber[800],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: Column(
        children: [
          // 1. KARTU TOTAL SALDO (REAL-TIME)
          _buildTotalKasCard(),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Menu Kelola", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),

          // 2. GRID MENU (7 MENU)
          Expanded(
            child: GridView.count(
              crossAxisCount: 2, // 2 kolom
              padding: const EdgeInsets.symmetric(horizontal: 20),
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              children: [
                _buildMenuContainer(
                  context,
                  title: "Input Transaksi",
                  icon: Icons.add_chart,
                  color: Colors.red,
                  page: const TambahTransaksiPage(),
                ),
                _buildMenuContainer(
                  context,
                  title: "Verifikasi Bayar", // INI MENU YANG TADI KURANG
                  icon: Icons.fact_check,
                  color: Colors.teal,
                  page: const VerifikasiBayarPage(),
                ),
                _buildMenuContainer(
                  context,
                  title: "Rekap Transaksi",
                  icon: Icons.list_alt,
                  color: Colors.blue,
                  page: const RekapPage(),
                ),
                _buildMenuContainer(
                  context,
                  title: "Tanggal Kas",
                  icon: Icons.calendar_month,
                  color: Colors.orange,
                  page: const KasSettingPage(),
                ),
                _buildMenuContainer(
                  context,
                  title: "Pengumuman",
                  icon: Icons.announcement,
                  color: Colors.purple,
                  page: const PengumumanPage(),
                ),
                _buildMenuContainer(
                  context,
                  title: "Reimburse",
                  icon: Icons.payments,
                  color: Colors.green,
                  page: const ReimbursePage(),
                ),
                _buildMenuContainer(
                  context,
                  title: "Status Anggota",
                  icon: Icons.group_off,
                  color: const Color.fromARGB(255, 10, 10, 10),
                  page: const StatusAnggotaPage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET HEADER SALDO
  Widget _buildTotalKasCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('transactions').snapshots(),
      builder: (context, snapshot) {
        int total = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            int jumlah = doc['jumlah'];
            doc['type'] == 'masuk' ? total += jumlah : total -= jumlah;
          }
        }
        final currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.amber[800],
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Total Saldo Kas Organisasi", style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 10),
              Text(
                currencyFormat.format(total),
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }

  // WIDGET KOTAK MENU
  Widget _buildMenuContainer(BuildContext context, {required String title, required IconData icon, required Color color, required Widget page}) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
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

  // DIALOG LOGOUT
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Keluar dari aplikasi?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              await AuthService().signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context, 
                MaterialPageRoute(builder: (_) => const LoginScreen()), 
                (route) => false
              );
            }, 
            child: const Text("Logout")
          ),
        ],
      ),
    );
  }
}