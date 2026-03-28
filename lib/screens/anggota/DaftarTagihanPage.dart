import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'bayar_kas_page.dart';

class DaftarTagihanPage extends StatefulWidget {
  const DaftarTagihanPage({super.key});

  @override
  State<DaftarTagihanPage> createState() => _DaftarTagihanPageState();
}

class _DaftarTagihanPageState extends State<DaftarTagihanPage> {
  final Color primaryNavy = const Color(0xFF1A237E);
  final Color backgroundColor = const Color(0xFFF4F6F8);

  final String currentUserUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  String? _userGroupId;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserGroupId();
  }

  Future<void> _loadUserGroupId() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserUid)
        .get();

    if (userDoc.exists) {
      setState(() {
        _userGroupId = userDoc['groupId'];
        _isLoadingUser = false;
      });
    }
  }

  String _formatCurrency(int value) {
    return NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryNavy,
        title: const Text(
          "Tagihan Kas",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingUser
          ? Center(child: CircularProgressIndicator(color: primaryNavy))
          : Stack(
              children: [
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: primaryNavy,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                ),
                Column(
                  children: [
                    _buildInfoBox(),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('kas_deadline')
                            .where('groupId', isEqualTo: _userGroupId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Center(child: CircularProgressIndicator(color: primaryNavy));
                          }

                          final list = snapshot.data!.docs;
                          if (list.isEmpty) {
                            return _buildEmptyState();
                          }

                          // Sort berdasarkan deadline terbaru
                          list.sort((a, b) => (b['tanggal_deadline'] as Timestamp)
                              .compareTo(a['tanggal_deadline'] as Timestamp));

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                            itemCount: list.length,
                            itemBuilder: (context, index) {
                              var d = list[index];
                              String bulan = d['bulan'];
                              int nominal = d['nominal'];
                              DateTime deadline = (d['tanggal_deadline'] as Timestamp).toDate();

                              // 🔥 CEK STATUS PEMBAYARAN USER
                              return StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('pembayaran')
                                    .doc("${currentUserUid}_$bulan") // ID unik: UID_Bulan
                                    .snapshots(),
                                builder: (context, paySnap) {
                                  if (!paySnap.hasData) return const SizedBox();

                                  // Jika data pembayaran ada
                                  if (paySnap.data!.exists) {
                                    String status = paySnap.data!['status'];

                                    // 1. JIKA DITERIMA -> CARD HILANG
                                    if (status == 'disetujui' || status == 'sukses') {
                                      return const SizedBox.shrink();
                                    }

                                    // 2. JIKA PENDING / DITOLAK -> TAMPILKAN DENGAN STATUS
                                    return _buildNavyCard(bulan, nominal, deadline, status);
                                  }

                                  // 3. JIKA BELUM BAYAR -> TAMPILKAN CARD NORMAL
                                  return _buildNavyCard(bulan, nominal, deadline, 'belum_bayar');
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildNavyCard(String bulan, int nominal, DateTime deadline, String status) {
    bool isOverdue = DateTime.now().isAfter(deadline);
    
    // Konfigurasi UI berdasarkan status
    Color statusColor = primaryNavy;
    String btnText = "Bayar";
    String statusLabel = "";
    bool isPending = status == 'pending';
    bool isRejected = status == 'ditolak';

    if (isPending) {
      statusColor = Colors.orange;
      btnText = "Proses";
      statusLabel = "Menunggu Verifikasi";
    } else if (isRejected) {
      statusColor = Colors.red;
      btnText = "Bayar Lagi";
      statusLabel = "Ditolak (Bayar Ulang)";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                isRejected ? Icons.error_outline_rounded : Icons.receipt_long_rounded, 
                color: statusColor
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Bulan $bulan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy)),
                  const SizedBox(height: 4),
                  Text(_formatCurrency(nominal), style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  
                  // Label Status (Hanya muncul jika pending/ditolak)
                  if (statusLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),

                  Row(
                    children: [
                      Icon(Icons.event_note_rounded, size: 14, color: isOverdue ? Colors.red : Colors.grey),
                      const SizedBox(width: 5),
                      Text(
                        "Batas: ${DateFormat('dd MMM yyyy').format(deadline)}",
                        style: TextStyle(color: isOverdue ? Colors.red : Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // TOMBOL
            ElevatedButton(
              onPressed: isPending ? null : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BayarKasPage(
                      bulan: bulan,
                      nominal: nominal,
                      deadline: deadline,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(btnText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: primaryNavy, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Jika tagihan hilang, berarti pembayaran Anda sudah diterima oleh admin.",
                style: TextStyle(fontSize: 12, color: Colors.grey[800]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 10),
          const Text("Semua tagihan lunas atau tidak ada iuran.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}