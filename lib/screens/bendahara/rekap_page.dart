import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'edit_transaksi_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/error_service.dart';

class RekapPage extends StatefulWidget {
  const RekapPage({super.key});

  @override
  State<RekapPage> createState() => _RekapPageState();
}

class _RekapPageState extends State<RekapPage> {
  String? _userGroupId;
  bool _isLoadingGroupId = true;

  final _currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');
  final Color primaryNavy = const Color(0xFF1A237E);

  @override
  void initState() {
    super.initState();
    _loadUserGroupId();
  }

  Future<void> _loadUserGroupId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && mounted) {
          setState(() {
            _userGroupId = userDoc['groupId'];
            _isLoadingGroupId = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorService.show(context, e);
        setState(() => _isLoadingGroupId = false);
      }
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return "Proses...";
    if (ts is Timestamp) return _dateFormat.format(ts.toDate());
    return "-";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryNavy,
        title: const Text("Riwayat Kas", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingGroupId
          ? Center(child: CircularProgressIndicator(color: primaryNavy))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .where('groupId', isEqualTo: _userGroupId)
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return _buildErrorState(snapshot.error.toString());
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

                return Column(
                  children: [
                    _buildSummaryHeader(snapshot.data!.docs),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var doc = snapshot.data!.docs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          return _buildTransactionCard(doc.id, data);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // Widget tambahan untuk ringkasan cepat di atas list
  Widget _buildSummaryHeader(List<QueryDocumentSnapshot> docs) {
    double total = 0;
    for (var doc in docs) {
      var data = doc.data() as Map<String, dynamic>;
      double amt = (data['jumlah'] ?? 0).toDouble();
      data['type'] == 'masuk' ? total += amt : total -= amt;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryNavy,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const Text("Total Saldo Grup", style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 5),
          Text(_currencyFormat.format(total),
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(String id, Map<String, dynamic> data) {
    bool isMasuk = data['type'] == 'masuk';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMasuk ? Colors.green[50] : Colors.red[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            isMasuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: isMasuk ? Colors.green : Colors.red,
            size: 20,
          ),
        ),
        title: Text(data['keterangan'] ?? "-", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_formatDate(data['date']), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${isMasuk ? '+' : '-'} ${_currencyFormat.format(data['jumlah'] ?? 0)}",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isMasuk ? Colors.green[700] : Colors.red[700],
              ),
            ),
            _buildPopupMenu(id, data),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupMenu(String id, Map<String, dynamic> data) {
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (value) {
        if (value == 'edit') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => EditTransaksiPage(docId: id, currentData: data)));
        } else if (value == 'delete') {
          _confirmDelete(context, id);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text("Edit")])),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text("Hapus", style: TextStyle(color: Colors.red))])),
      ],
      icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 15),
          Text("Belum ada riwayat transaksi", style: TextStyle(color: Colors.grey[400])),
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
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 10),
            Text("Gagal memuat data. Periksa Index Firestore Anda.", textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hapus Transaksi?"),
        content: const Text("Tindakan ini tidak dapat dibatalkan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Batal")),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await FirebaseFirestore.instance.collection('transactions').doc(id).delete();
                if (!context.mounted) return;
                ErrorService.showSuccess(context, "Transaksi dihapus");
              } catch (e) {
                if (context.mounted) ErrorService.show(context, e);
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}