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

  // Optimasi: Definisikan formatters di luar build agar hemat memori
  final _currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

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
            _isLoadingGroupId = false;
          });
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ErrorService.show(context, e);
      if (mounted) setState(() => _isLoadingGroupId = false);
    }
  }

  String _formatCurrency(double value) {
    return _currencyFormat.format(value);
  }

  String _formatDate(dynamic ts) {
    // Safety check: jika server timestamp belum turun, gunakan waktu sekarang sebagai placeholder
    if (ts == null) return "..."; 
    if (ts is Timestamp) {
      return _dateFormat.format(ts.toDate());
    }
    return "-";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        title: const Text("Rekap Transaksi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingGroupId
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .where('groupId', isEqualTo: _userGroupId)
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // Handle error index atau koneksi
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        "Pastikan Index Firestore sudah dibuat atau cek koneksi.\nError: ${snapshot.error}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String id = doc.id;
                    bool isMasuk = data['type'] == 'masuk';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isMasuk ? Colors.green[50] : Colors.red[50],
                          child: Icon(
                            isMasuk ? Icons.add_circle_outline : Icons.remove_circle_outline,
                            color: isMasuk ? Colors.green : Colors.red,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          data['keterangan'] ?? "-",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            // Gunakan helper formatDate yang aman
                            Text(_formatDate(data['date']), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(isMasuk ? 'Uang Masuk' : 'Uang Keluar', 
                              style: TextStyle(fontSize: 11, color: isMasuk ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${isMasuk ? '+' : '-'} ${_formatCurrency((data['jumlah'] ?? 0).toDouble())}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isMasuk ? Colors.green[700] : Colors.red[700],
                              ),
                            ),
                            const SizedBox(width: 5),
                            _buildPopupMenu(context, id, data),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildPopupMenu(BuildContext context, String id, Map<String, dynamic> data) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => EditTransaksiPage(docId: id, currentData: data),
          ));
        } else if (value == 'delete') {
          _confirmDelete(context, id);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit")])),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Hapus", style: TextStyle(color: Colors.red))])),
      ],
      icon: const Icon(Icons.more_vert, color: Colors.grey),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 15),
          Text("Belum ada riwayat transaksi\ndi grup ini.", 
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Hapus Transaksi?"),
        content: const Text("Data ini akan dihapus permanen dari riwayat grup."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                // Tutup dialog dulu
                Navigator.pop(dialogContext);
                
                // Jalankan proses hapus
                await FirebaseFirestore.instance.collection('transactions').doc(id).delete();
                
                if (!context.mounted) return;
                ErrorService.showSuccess(context, "Transaksi berhasil dihapus");
              } catch (e) {
                if (!context.mounted) return;
                ErrorService.show(context, e);
              }
            },
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }
}