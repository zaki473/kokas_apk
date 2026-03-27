import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CashFlowPage extends StatelessWidget {
  const CashFlowPage({super.key});

  // Fungsi Format Rupiah
  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  // Fungsi Format Tanggal
  String _formatDate(Timestamp ts) {
    return DateFormat('dd MMM yyyy').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E), // Navy Dashboard
        title: const Text("Riwayat Cash Flow", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Header Melengkung
          Container(
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
          
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }
              
              return ListView.builder(
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

  // WIDGET CARD TRANSAKSI (GAYA PREMIUM)
  Widget _buildTransactionCard(Map<String, dynamic> data, bool isMasuk) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
          data['keterangan'] ?? "-",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2D3142)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatDate(data['date']),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        trailing: Text(
          "${isMasuk ? '+' : '-'} ${_formatCurrency((data['jumlah'] ?? 0).toDouble())}",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: isMasuk ? Colors.green[700] : Colors.red[700],
          ),
        ),
      ),
    );
  }

  // TAMPILAN JIKA DATA KOSONG
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text(
            "Belum ada riwayat transaksi",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}