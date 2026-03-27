import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatusAnggotaPage extends StatefulWidget {
  const StatusAnggotaPage({super.key});

  @override
  State<StatusAnggotaPage> createState() => _StatusAnggotaPageState();
}

class _StatusAnggotaPageState extends State<StatusAnggotaPage> {
  String? _selectedBulan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E), // Navy Dashboard
        title: const Text("Monitoring Kas", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Header Navy
          Container(
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),

          Column(
            children: [
              // 1. DROPDOWN PILIH BULAN (MODERN BOX)
              _buildDropdownSection(),

              const SizedBox(height: 10),

              // 2. LIST ANGGOTA
              Expanded(
                child: _buildMemberList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // WIDGET DROPDOWN PREMIUM
  Widget _buildDropdownSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('kas_deadline').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LinearProgressIndicator();
          
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Belum ada daftar tagihan."));

          if (_selectedBulan == null && docs.isNotEmpty) {
            _selectedBulan = docs.first['bulan'];
          }

          return DropdownButtonFormField<String>(
            isExpanded: true,
            value: _selectedBulan,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1A237E)),
            decoration: InputDecoration(
              labelText: "Pilih Periode Iuran",
              labelStyle: const TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.w500),
              prefixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF1A237E), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            ),
            items: docs.map((d) {
              return DropdownMenuItem(
                value: d['bulan'].toString(),
                child: Text(d['bulan'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedBulan = val),
          );
        },
      ),
    );
  }

  // WIDGET LIST SEMUA ANGGOTA
  Widget _buildMemberList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'anggota')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Tidak ada data anggota."));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
          itemBuilder: (context, index) {
            var user = snapshot.data!.docs[index];
            String uid = user.id;
            String email = user['email'];
            String namaPanggilan = email.split('@')[0].toUpperCase();

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pembayaran')
                  .doc("${uid}_$_selectedBulan")
                  .snapshots(),
              builder: (context, paySnap) {
                // Logika Status
                String statusText = "Belum Bayar";
                Color statusColor = Colors.red;
                IconData statusIcon = Icons.warning_amber_rounded;
                String badgeText = "TAGIH";

                if (paySnap.hasData && paySnap.data!.exists) {
                  String s = paySnap.data!['status'];
                  if (s == 'disetujui') {
                    statusText = "Lunas";
                    statusColor = Colors.green;
                    statusIcon = Icons.verified_rounded;
                    badgeText = "AMAN";
                  } else if (s == 'pending') {
                    statusText = "Menunggu Verifikasi";
                    statusColor = Colors.orange;
                    statusIcon = Icons.hourglass_top_rounded;
                    badgeText = "CEK";
                  } else if (s == 'ditolak') {
                    statusText = "Ditolak / Bermasalah";
                    statusColor = Colors.redAccent;
                    statusIcon = Icons.error_outline_rounded;
                    badgeText = "REVISI";
                  }
                }

                return _buildMemberCard(namaPanggilan, email, statusText, statusColor, statusIcon, badgeText);
              },
            );
          },
        );
      },
    );
  }

  // WIDGET KARTU ANGGOTA INDIVIDUAL
  Widget _buildMemberCard(String initial, String email, String status, Color color, IconData icon, String badge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          // Avatar dengan Inisial
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withOpacity(0.1),
            child: Text(
              initial.substring(0, 1),
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 15),
          
          // Informasi Nama & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3142)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Badge Aksi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))
              ],
            ),
            child: Text(
              badge,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}