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
      if (!context.mounted) return;
      ErrorService.show(context, e);
    }
  }

  String _formatCurrency(int value) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: primaryNavy)));
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
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: primaryNavy,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
          ),
          Column(
            children: [
              _buildInfoBox(),
              Expanded(
                // OPTIMASI: Gunakan StreamBuilder Utama untuk List Tagihan
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('kas_deadline')
                      .where('groupId', isEqualTo: _userGroupId)
                      .orderBy('tanggal_deadline', descending: true) // Pastikan sudah buat Composite Index di Firebase
                      .snapshots(),
                  builder: (context, deadlineSnap) {
                    if (deadlineSnap.hasError) return Center(child: Text("Terjadi kesalahan indeks."));
                    if (!deadlineSnap.hasData) return const Center(child: CircularProgressIndicator());

                    final listTagihan = deadlineSnap.data!.docs;
                    if (listTagihan.isEmpty) return _buildEmptyState();

                    // OPTIMASI: Gunakan StreamBuilder kedua hanya SEKALI untuk semua pembayaran user ini
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('pembayaran')
                          .where('uid_pengirim', isEqualTo: currentUserUid)
                          .snapshots(),
                      builder: (context, paySnap) {
                        if (!paySnap.hasData) return const Center(child: CircularProgressIndicator());

                        // Buat Map untuk lookup status pembayaran dengan cepat (O(1))
                        // Key: Bulan, Value: Status
                        Map<String, String> paymentStatusMap = {};
                        for (var doc in paySnap.data!.docs) {
                          paymentStatusMap[doc['bulan']] = doc['status'];
                        }

                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                          itemCount: listTagihan.length,
                          itemBuilder: (context, index) {
                            var d = listTagihan[index];
                            String bulan = d['bulan'];
                            int nominal = d['nominal'];
                            DateTime deadline = (d['tanggal_deadline'] as Timestamp).toDate();

                            String status = paymentStatusMap[bulan] ?? 'belum_bayar';

                            // JIKA DITERIMA -> JANGAN TAMPILKAN (Sesuai Logika Kamu)
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
      btnText = "Re-Bayar";
      statusLabel = "Ditolak (Bayar Ulang)";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            _buildIconStatus(isRejected, statusColor),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Iuran $bulan", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryNavy)),
                  Text(_formatCurrency(nominal), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  if (statusLabel.isNotEmpty)
                    Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.event_note_rounded, size: 12, color: isOverdue ? Colors.red : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        "Deadline: ${DateFormat('dd MMM').format(deadline)}",
                        style: TextStyle(color: isOverdue ? Colors.red : Colors.grey[600], fontSize: 11),
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
    );
  }

  Widget _buildIconStatus(bool isRejected, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Icon(isRejected ? Icons.warning_amber_rounded : Icons.receipt_long_rounded, color: color, size: 22),
    );
  }

  Widget _buildActionButton(String bulan, int nominal, DateTime deadline, Color color, String text, bool isPending) {
    return ElevatedButton(
      onPressed: isPending ? null : () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => BayarKasPage(bulan: bulan, nominal: nominal, deadline: deadline)));
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[200],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        elevation: 0,
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 10, 25, 5),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(15)),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: primaryNavy, size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text("Tagihan otomatis hilang jika sudah lunas diverifikasi.", style: TextStyle(fontSize: 11))),
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
          Icon(Icons.verified_rounded, size: 80, color: Colors.green[100]),
          const SizedBox(height: 10),
          const Text("Luar Biasa! Semua Tagihan Lunas.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}