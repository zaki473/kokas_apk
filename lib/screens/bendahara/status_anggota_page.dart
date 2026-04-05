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

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadGroupId();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
        if (mounted) {
          ErrorService.show(context, e);
          setState(() => _isLoadingGroup = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        title: const Text("Monitoring Kas",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingGroup
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header & Control Section
                Stack(
                  children: [
                    Container(
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A237E),
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          // Search Bar (Expanded agar fleksibel)
                          Expanded(child: _buildSearchBar()),
                          const SizedBox(width: 12),
                          // Dropdown (Fixed width agar presisi)
                          _buildCompactDropdown(),
                        ],
                      ),
                    ),
                  ],
                ),
                
                _buildLegend(),
                Expanded(child: _buildMemberList()),
              ],
            ),
    );
  }

  // --- UI: SEARCH BAR ---
  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: "Cari nama...",
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF1A237E), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
      ),
    );
  }

  // --- UI: COMPACT DROPDOWN ---
  Widget _buildCompactDropdown() {
    return Container(
      width: 130,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('kas_deadline')
            .where('groupId', isEqualTo: _bendaharaGroupId)
            .orderBy('tanggal_deadline', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)));

          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Kosong", style: TextStyle(fontSize: 10)));

          if (_selectedBulan == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _selectedBulan = docs.first['bulan'];
                _selectedDeadline = (docs.first['tanggal_deadline'] as Timestamp).toDate();
              });
            });
          }

          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedBulan,
              icon: const Icon(Icons.filter_list_rounded, color: Color(0xFF1A237E), size: 20),
              items: docs.map((d) {
                return DropdownMenuItem(
                  value: d['bulan'].toString(),
                  child: Text(d['bulan'], 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, overflow: TextOverflow.ellipsis)),
                );
              }).toList(),
              onChanged: (val) {
                var selectedDoc = docs.firstWhere((d) => d['bulan'] == val);
                setState(() {
                  _selectedBulan = val;
                  _selectedDeadline = (selectedDoc['tanggal_deadline'] as Timestamp).toDate();
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Daftar Anggota", 
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 15)),
          if (_selectedDeadline != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
              child: Text(
                "Deadline: ${_selectedDeadline!.day}/${_selectedDeadline!.month}/${_selectedDeadline!.year}",
                style: const TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberList() {
    if (_selectedBulan == null) return const Center(child: Text("Memuat periode..."));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('groupId', isEqualTo: _bendaharaGroupId)
          .where('role', isEqualTo: 'anggota')
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var allUsers = userSnapshot.data!.docs;
        if (allUsers.isEmpty) return _buildEmptyState("Grup ini belum memiliki anggota.");

        var filteredUsers = allUsers.where((user) {
          var data = user.data() as Map<String, dynamic>;
          String nama = (data['name'] ?? "").toString().toLowerCase();
          return nama.contains(_searchQuery);
        }).toList();

        if (filteredUsers.isEmpty) return _buildEmptyState("Nama anggota tidak ditemukan.");

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('pembayaran')
              .where('groupId', isEqualTo: _bendaharaGroupId)
              .where('bulan', isEqualTo: _selectedBulan)
              .snapshots(),
          builder: (context, paySnapshot) {
            Map<String, String> statusMap = {};
            if (paySnapshot.hasData) {
              for (var doc in paySnapshot.data!.docs) {
                statusMap[doc['uid_pengirim']] = doc['status'];
              }
            }

            return ListView.builder(
              itemCount: filteredUsers.length,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              itemBuilder: (context, index) {
                var user = filteredUsers[index];
                String memberUid = user['uid'];
                String nama = user['name'] ?? "Anggota";
                String email = user['email'] ?? "-";

                String? s = statusMap[memberUid];
                DateTime now = DateTime.now();
                bool isOverdue = _selectedDeadline != null && now.isAfter(_selectedDeadline!);

                String statusText = isOverdue ? "Menunggak" : "Belum Bayar";
                Color statusColor = isOverdue ? Colors.blueGrey[900]! : Colors.red[700]!;
                IconData statusIcon = isOverdue ? Icons.timer_off_outlined : Icons.info_outline;
                String badgeText = isOverdue ? "TELAT" : "TAGIH";

                if (s == 'disetujui') {
                  // Cek apakah dia bayarnya pas sudah lewat deadline
                  // (Idealnya kamu simpan 'tanggal_bayar' di Firestore untuk pengecekan yang lebih akurat)
                  statusText = isOverdue ? "Lunas (Terlambat)" : "Lunas";
                  statusColor = isOverdue ? Colors.teal : Colors.green[700]!;
                  statusIcon = Icons.check_circle_rounded;
                  badgeText = "AMAN";
                } else if (s == 'pending') {
                  statusText = "Menunggu Verifikasi";
                  statusColor = Colors.orange[800]!;
                  statusIcon = Icons.hourglass_empty_rounded;
                  badgeText = "CEK";
                } else if (s == 'ditolak') {
                  statusText = "Ditolak (Butuh Revisi)";
                  statusColor = Colors.redAccent;
                  statusIcon = Icons.highlight_off_rounded;
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

  Widget _buildMemberCard(String nama, String email, String status, Color color, IconData icon, String badge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[50]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withOpacity(0.1),
            child: Text(nama.isNotEmpty ? nama[0].toUpperCase() : "?", 
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3142))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 5),
                    Flexible(child: Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600))),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(msg, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      ),
    );
  }
}