import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'bayar_kas_page.dart';
import '/services/error_service.dart';

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
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          _userGroupId = userDoc['groupId'];
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ErrorService.show(context, e);
    }
  }

  String _formatCurrency(int value) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryNavy))
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryNavy,
        title: const Text("Tagihan Kas", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Header
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: primaryNavy,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30), 
                bottomRight: Radius.circular(30)
              ),
            ),
          ),
          Column(
            children: [
              _buildInfoBox(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  // Note: Pastikan sudah membuat Index di Firebase Console untuk query ini
                  stream: FirebaseFirestore.instance
                      .collection('kas_deadline')
                      .where('groupId', isEqualTo: _userGroupId)
                      .orderBy('tanggal_deadline', descending: true)
                      .snapshots(),
                  builder: (context, deadlineSnap) {
                    if (deadlineSnap.hasError) {
                      debugPrint(deadlineSnap.error.toString());
                      return const Center(child: Text("Gagal memuat data. Periksa indeks Firestore."));
                    }
                    if (!deadlineSnap.hasData) return const Center(child: CircularProgressIndicator());

                    final listTagihan = deadlineSnap.data!.docs;
                    if (listTagihan.isEmpty) return _buildEmptyState();

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('pembayaran')
                          .where('uid_pengirim', isEqualTo: currentUserUid)
                          .snapshots(),
                      builder: (context, paySnap) {
                        if (!paySnap.hasData) return const Center(child: CircularProgressIndicator());

                        // Lookup Map untuk efisiensi O(1)
                        Map<String, String> paymentStatusMap = {};
                        for (var doc in paySnap.data!.docs) {
                          paymentStatusMap[doc['bulan']] = doc['status'];
                        }

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                          itemCount: listTagihan.length,
                          itemBuilder: (context, index) {
                            var d = listTagihan[index];
                            String bulan = d['bulan'];
                            int nominal = d['nominal'];
                            DateTime deadline = (d['tanggal_deadline'] as Timestamp).toDate();

                            String status = paymentStatusMap[bulan] ?? 'belum_bayar';

                            // Sembunyikan jika sudah sukses/disetujui
                            if (status == 'disetujui' || status == 'sukses') {
                              return const SizedBox.shrink();
                            }

                            return _buildNavyCard(bulan, nominal, deadline, status);
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
    
    Color statusColor = primaryNavy;
    String btnText = "BAYAR";
    String statusLabel = "";
    bool isPending = status == 'pending';
    bool isRejected = status == 'ditolak';

    if (isPending) {
      statusColor = Colors.orange;
      btnText = "PROSES";
      statusLabel = "Menunggu Verifikasi";
    } else if (isRejected) {
      statusColor = Colors.red;
      btnText = "RE-BAYAR";
      statusLabel = "Ditolak (Bayar Ulang)";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 12, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: statusColor, width: 6)),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Iuran $bulan", 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(nominal), 
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)
                    ),
                    const SizedBox(height: 8),
                    if (statusLabel.isNotEmpty) ...[
                      Text(
                        statusLabel, 
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: isOverdue ? Colors.red : Colors.grey[600]),
                        const SizedBox(width: 5),
                        Text(
                          "Deadline: ${DateFormat('dd MMM yyyy').format(deadline)}",
                          style: TextStyle(color: isOverdue ? Colors.red : Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildActionButton(bulan, nominal, deadline, statusColor, btnText, isPending),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String bulan, int nominal, DateTime deadline, Color color, String text, bool isPending) {
    return ElevatedButton(
      onPressed: isPending ? null : () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => BayarKasPage(bulan: bulan, nominal: nominal, deadline: deadline))
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[200],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 0,
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }

  Widget _buildInfoBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 15, 25, 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95), 
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: primaryNavy, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Tagihan otomatis hilang jika sudah diverifikasi oleh bendahara.", 
                style: TextStyle(fontSize: 11.5, color: Colors.black87, height: 1.3)
              )
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green),
          ),
          const SizedBox(height: 20),
          const Text(
            "Semua Tagihan Lunas!", 
            style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 8),
          Text(
            "Terima kasih sudah membayar tepat waktu.", 
            style: TextStyle(color: Colors.grey[600], fontSize: 14)
          ),
        ],
      ),
    );
  }
}