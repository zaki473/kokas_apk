import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:intl/intl.dart';

class StatusAnggotaPage extends StatefulWidget {
  const StatusAnggotaPage({super.key});

  @override
  State<StatusAnggotaPage> createState() => _StatusAnggotaPageState();
}

class _StatusAnggotaPageState extends State<StatusAnggotaPage> {
  String? _selectedBulan;
  DateTime? _selectedDeadline;
  
  // Ambil UID Bendahara yang sedang login (sebagai Group ID)
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        title: const Text("Monitoring Kas Grup",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
              // 1. DROPDOWN PILIH BULAN (Hanya milik grup ini)
              _buildDropdownSection(),

              const SizedBox(height: 10),

              // 2. LIST ANGGOTA (Hanya milik grup ini)
              Expanded(
                child: _buildMemberList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // WIDGET DROPDOWN PERIODE
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
        // FILTER: Hanya ambil tagihan yang dibuat oleh bendahara ini
        stream: FirebaseFirestore.instance
            .collection('kas_deadline')
            .where('groupId', isEqualTo: myUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LinearProgressIndicator());
          }
          
          var docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(15.0),
              child: Center(child: Text("Belum ada tagihan di grup Anda.")),
            );
          }

          // Auto-select bulan pertama jika belum ada yang terpilih
          if (_selectedBulan == null && docs.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _selectedBulan = docs.first['bulan'];
                _selectedDeadline = (docs.first['tanggal_deadline'] as Timestamp).toDate();
              });
            });
          }

          return DropdownButtonFormField<String>(
            isExpanded: true,
            value: _selectedBulan,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1A237E)),
            decoration: const InputDecoration(
              labelText: "Pilih Periode Iuran",
              labelStyle: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.w500),
              prefixIcon: Icon(Icons.calendar_today_rounded, color: Color(0xFF1A237E), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            ),
            items: docs.map((d) {
              return DropdownMenuItem(
                value: d['bulan'].toString(),
                child: Text(d['bulan'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              );
            }).toList(),
            onChanged: (val) {
              var selectedDoc = docs.firstWhere((d) => d['bulan'] == val);
              setState(() {
                _selectedBulan = val;
                _selectedDeadline = (selectedDoc['tanggal_deadline'] as Timestamp).toDate();
              });
            },
          );
        },
      ),
    );
  }

  // WIDGET LIST ANGGOTA
  Widget _buildMemberList() {
    if (_selectedBulan == null) {
      return const Center(child: Text("Silahkan pilih periode iuran."));
    }

    return StreamBuilder<QuerySnapshot>(
      // FILTER: Hanya ambil anggota yang memiliki groupId yang sama dengan bendahara
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'anggota')
          .where('groupId', isEqualTo: myUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("Belum ada anggota yang bergabung di grup Anda.");
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
          itemBuilder: (context, index) {
            var user = snapshot.data!.docs[index];
            String memberUid = user['uid'];
            String nama = user['name'] ?? "Anggota";
            String email = user['email'] ?? "-";

            // CEK STATUS PEMBAYARAN ANGGOTA INI
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pembayaran')
                  .where('uid_pengirim', isEqualTo: memberUid)
                  .where('bulan', isEqualTo: _selectedBulan)
                  .where('groupId', isEqualTo: myUid)
                  .limit(1)
                  .snapshots(),
              builder: (context, paySnap) {
                // Logika Deadline
                DateTime now = DateTime.now();
                bool isOverdue = _selectedDeadline != null && now.isAfter(_selectedDeadline!);

                // Default Status (Belum Bayar)
                String statusText = isOverdue ? "Menunggak (Lewat Deadline)" : "Belum Bayar";
                Color statusColor = isOverdue ? Colors.blueGrey[900]! : Colors.red[700]!;
                IconData statusIcon = isOverdue ? Icons.timer_off_outlined : Icons.warning_amber_rounded;
                String badgeText = isOverdue ? "TELAT" : "TAGIH";

                // Jika data pembayaran ditemukan
                if (paySnap.hasData && paySnap.data!.docs.isNotEmpty) {
                  var payData = paySnap.data!.docs.first.data() as Map<String, dynamic>;
                  String s = payData['status'];

                  if (s == 'disetujui') {
                    statusText = "Lunas";
                    statusColor = Colors.green[700]!;
                    statusIcon = Icons.verified_rounded;
                    badgeText = "AMAN";
                  } else if (s == 'pending') {
                    statusText = "Menunggu Verifikasi";
                    statusColor = Colors.orange[800]!;
                    statusIcon = Icons.hourglass_top_rounded;
                    badgeText = "CEK";
                  } else if (s == 'ditolak') {
                    statusText = "Pembayaran Ditolak";
                    statusColor = Colors.redAccent;
                    statusIcon = Icons.error_outline_rounded;
                    badgeText = "REVISI";
                  }
                }

                return _buildMemberCard(nama, email, statusText, statusColor, statusIcon, badgeText);
              },
            );
          },
        );
      },
    );
  }

  // WIDGET KARTU ANGGOTA
  Widget _buildMemberCard(String nama, String email, String status, Color color, IconData icon, String badge) {
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
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withOpacity(0.1),
            child: Text(
              nama.substring(0, 1).toUpperCase(),
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3142)),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                Text(
                  email,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        status,
                        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
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

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 15),
            Text(msg, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}