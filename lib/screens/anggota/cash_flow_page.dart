import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '/services/error_service.dart';

class CashFlowPage extends StatefulWidget {
  const CashFlowPage({super.key});

  @override
  State<CashFlowPage> createState() => _CashFlowPageState();
}

class _CashFlowPageState extends State<CashFlowPage> {
  final Color primaryNavy = const Color(0xFF1A237E);
  final Color backgroundColor = const Color(0xFFF4F6F8);
  
  String? _userGroupId;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserGroupId();
  }

  Future<void> _loadUserGroupId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && mounted) {
          setState(() {
            _userGroupId = userDoc['groupId'];
            _isLoadingUser = false;
          });
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ErrorService.show(context, e);
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return "-"; // Safety check jika tanggal kosong
    if (ts is Timestamp) {
      return DateFormat('dd MMM yyyy').format(ts.toDate());
    }
    return "-";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryNavy,
        title: const Text("Riwayat Cash Flow", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingUser 
      ? Center(child: CircularProgressIndicator(color: primaryNavy))
      : Stack(
          children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: primaryNavy,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
            ),
            
            StreamBuilder<QuerySnapshot>(
              // Optimasi: Tambahkan .limit untuk mencegah aplikasi lemot jika data ribuan
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .where('groupId', isEqualTo: _userGroupId)
                  .orderBy('date', descending: true)
                  .limit(100) // Ambil 100 transaksi terakhir saja untuk performa
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  // Jika muncul error index, cek konsol dan klik link yang diberikan Firebase
                  return _buildErrorState(snapshot.error.toString());
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }
                
                return ListView.builder(
                  // physics agar scroll terasa premium
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    bool isMasuk = data['type'] == 'masuk';

                    return _buildTransactionCard(data, isMasuk);
                  },
                );
              },
            ),
          ],
        ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> data, bool isMasuk) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMasuk ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            isMasuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: isMasuk ? Colors.green[700] : Colors.red[700],
            size: 24,
          ),
        ),
        title: Text(
          data['keterangan'] ?? "Tanpa Keterangan",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3142)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _formatDate(data['date']),
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ),
        trailing: Text(
          "${isMasuk ? '+' : '-'} ${_formatCurrency((data['jumlah'] ?? 0).toDouble())}",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            color: isMasuk ? Colors.green[700] : Colors.red[700],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          const Text(
            "Belum ada riwayat transaksi",
            style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 50),
            const SizedBox(height: 10),
            const Text("Oops! Terjadi kesalahan.", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(
              error.contains("index") ? "Database memerlukan sinkronisasi indeks. Silakan hubungi pengembang." : error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}