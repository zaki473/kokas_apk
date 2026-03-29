import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/error_service.dart'; 

class StatusAnggotaPage extends StatefulWidget {
  const StatusAnggotaPage({super.key});

  @override
  State<StatusAnggotaPage> createState() => _StatusAnggotaPageState();
}

class _StatusAnggotaPageState extends State<StatusAnggotaPage> {
  String? _selectedBulan;
  DateTime? _selectedDeadline;
  String? _bendaharaGroupId;
  bool _isLoadingGroup = true;

  @override
  void initState() {
    super.initState();
    _loadGroupId();
  }

  // Load Group ID yang benar
  Future<void> _loadGroupId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted) {
          setState(() {
            _bendaharaGroupId = doc.data()?['groupId'];
            _isLoadingGroup = false;
          });
        }
      } catch (e) {
        if (!context.mounted) return;
        ErrorService.show(context, e);
        if (mounted) ErrorService.show(context, e);
      }
    }
  }

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
      body: _isLoadingGroup 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              Container(
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A237E),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                ),
              ),
              Column(
                children: [
                  _buildDropdownSection(),
                  const SizedBox(height: 10),
                  Expanded(child: _buildMemberList()),
                ],
              ),
            ],
          ),
    );
  }

  Widget _buildDropdownSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('kas_deadline')
            .where('groupId', isEqualTo: _bendaharaGroupId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LinearProgressIndicator();
          
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(15.0),
              child: Center(child: Text("Belum ada tagihan di grup Anda.")),
            );
          }

          // Logika Auto-select yang lebih aman
          if (_selectedBulan == null) {
            final firstDoc = docs.first;
            _selectedBulan = firstDoc['bulan'];
            _selectedDeadline = (firstDoc['tanggal_deadline'] as Timestamp).toDate();
          }

          return DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedBulan,
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
                child: Text(d['bulan'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  Widget _buildMemberList() {
    if (_selectedBulan == null) return const Center(child: Text("Silahkan pilih periode iuran."));

    // OPTIMASI: Gunakan 1 StreamBuilder saja untuk list anggota
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'anggota')
          .where('groupId', isEqualTo: _bendaharaGroupId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (userSnapshot.data!.docs.isEmpty) return _buildEmptyState("Belum ada anggota.");

        // OPTIMASI: Stream status pembayaran sekaligus untuk semua anggota di bulan tersebut
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('pembayaran')
              .where('bulan', isEqualTo: _selectedBulan)
              .where('groupId', isEqualTo: _bendaharaGroupId)
              .snapshots(),
          builder: (context, paySnapshot) {
            // Kita buat Map agar pencarian status per-anggota menjadi O(1) / sangat cepat
            Map<String, String> statusMap = {};
            if (paySnapshot.hasData) {
              for (var doc in paySnapshot.data!.docs) {
                statusMap[doc['uid_pengirim']] = doc['status'];
              }
            }

            return ListView.builder(
              itemCount: userSnapshot.data!.docs.length,
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
              itemBuilder: (context, index) {
                var user = userSnapshot.data!.docs[index];
                String memberUid = user['uid'];
                String nama = user['name'] ?? "Anggota";
                String email = user['email'] ?? "-";

                // Logika Status
                String? s = statusMap[memberUid];
                DateTime now = DateTime.now();
                bool isOverdue = _selectedDeadline != null && now.isAfter(_selectedDeadline!);

                String statusText = isOverdue ? "Menunggak (Lewat Deadline)" : "Belum Bayar";
                Color statusColor = isOverdue ? const Color(0xFF263238) : Colors.red[700]!;
                IconData statusIcon = isOverdue ? Icons.timer_off_outlined : Icons.warning_amber_rounded;
                String badgeText = isOverdue ? "TELAT" : "TAGIH";

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

                return _buildMemberCard(nama, email, statusText, statusColor, statusIcon, badgeText);
              },
            );
          },
        );
      },
    );
  }

  // --- UI WIDGETS (TETAP SAMA SEPERTI ASLI) ---
  Widget _buildMemberCard(String nama, String email, String status, Color color, IconData icon, String badge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Text(nama.isNotEmpty ? nama[0].toUpperCase() : "?", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3142)), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(email, style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 5),
                    Flexible(child: Text(status, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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