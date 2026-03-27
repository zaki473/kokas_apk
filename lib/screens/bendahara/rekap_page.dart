import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'edit_transaksi_page.dart';

class RekapPage extends StatelessWidget {
  const RekapPage({super.key});

  // Fungsi Format Rupiah
  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  // Fungsi Format Tanggal
  String _formatDate(Timestamp ts) {
    return DateFormat('dd MMM yyyy, HH:mm').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Latar belakang putih bersih
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E), // Navy Dashboard
        title: const Text("Rekap Transaksi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }
          
          return ListView.separated(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String id = doc.id;
              bool isMasuk = data['type'] == 'masuk';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                leading: CircleAvatar(
                  backgroundColor: isMasuk ? Colors.green[50] : Colors.red[50],
                  child: Icon(
                    isMasuk ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isMasuk ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ),
                title: Text(
                  data['keterangan'] ?? "-",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Text(
                  "${_formatDate(data['date'])}\n${isMasuk ? 'Masuk' : 'Keluar'}",
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatCurrency((data['jumlah'] ?? 0).toDouble()),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isMasuk ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildPopupMenu(context, id, data),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // WIDGET POPUP MENU UNTUK EDIT/HAPUS (LEBIH BERSIH)
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
        const PopupMenuItem(value: 'edit', child: Text("Edit")),
        const PopupMenuItem(value: 'delete', child: Text("Hapus", style: TextStyle(color: Colors.red))),
      ],
      icon: const Icon(Icons.more_vert, color: Colors.grey),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("Tidak ada transaksi", style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus?"),
        content: const Text("Data transaksi ini akan dihapus permanen."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('transactions').doc(id).delete();
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}