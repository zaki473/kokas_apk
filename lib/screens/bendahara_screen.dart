import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'bendahara/rekap_page.dart';
import 'bendahara/kas_setting_page.dart';
import 'bendahara/pengumuman_page.dart';
import 'bendahara/reimburse_page.dart';
import 'bendahara/tambah_transaksi_page.dart';

class BendaharaScreen extends StatelessWidget {
  const BendaharaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Dashboard Bendahara"),
        backgroundColor: Colors.amber[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Logout"),
                    content: const Text("Apakah kamu yakin ingin keluar?"),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // tutup popup
                        },
                        child: const Text("Batal"),
                      ),

                      ElevatedButton(
                        onPressed: () {
                          AuthService().signOut().then(
                            (_) => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
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
          // --- BAGIAN ATAS: TOTAL KAS ---
          _buildTotalKasCard(),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Menu Utama",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // --- BAGIAN BAWAH: MENU CONTAINER ---
          Expanded(
            child: GridView.count(
              crossAxisCount: 2, // 2 Kolom
              padding: const EdgeInsets.all(20),
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              children: [
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
                  title: "Input Transaksi",
                  icon: Icons.add_chart,
                  color: Colors.red,
                  page:
                      const TambahTransaksiPage(), // Navigasi ke halaman baru tadi
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET TOTAL KAS (MENGHITUNG OTOMATIS DARI FIRESTORE)
  Widget _buildTotalKasCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.amber[700],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Total Saldo Kas",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Text(
                  "Rp 0",
                  style: TextStyle(color: Colors.white, fontSize: 30),
                );

              // Logika hitung total: Masuk - Keluar
              int total = 0;
              for (var doc in snapshot.data!.docs) {
                int jumlah = doc['jumlah'];
                if (doc['type'] == 'masuk') {
                  total += jumlah;
                } else {
                  total -= jumlah;
                }
              }

              final currencyFormat = NumberFormat.currency(
                locale: 'id',
                symbol: 'Rp ',
                decimalDigits: 0,
              );
              return Text(
                currencyFormat.format(total),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // WIDGET KOTAK MENU
  Widget _buildMenuContainer(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget page,
  }) {
    return InkWell(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
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
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
