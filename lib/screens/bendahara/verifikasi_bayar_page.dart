import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class VerifikasiBayarPage extends StatelessWidget {
  const VerifikasiBayarPage({super.key});

  // Fungsi Format Rupiah
  String formatCurrency(double value) {
    return NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  // Fungsi untuk menampilkan foto ukuran penuh (Bukti Transfer)
  void _showImagePreview(BuildContext context, String base64String) {
    if (base64String.isEmpty) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Close",
      barrierColor: Colors.black.withOpacity(
        0.9,
      ), // Background hitam pekat agar fokus ke gambar
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                // Area Gambar yang bisa di Zoom
                Center(
                  child: InteractiveViewer(
                    clipBehavior: Clip.none,
                    minScale: 0.5,
                    maxScale: 5.0, // Maksimal zoom 5x
                    child: Hero(
                      tag:
                          'preview_image', // Opsional: Beri tag jika ingin animasi transisi
                      child: Image.memory(
                        base64Decode(base64String),
                        fit: BoxFit
                            .contain, // Memastikan gambar panjang/lebar muat di layar
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 50,
                            ),
                      ),
                    ),
                  ),
                ),

                // Tombol Close di pojok kanan atas
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 35,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // Keterangan cara zoom (opsional)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: const Center(
                    child: Text(
                      "Cubit untuk zoom • Geser untuk geser",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _prosesTerima(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;

      await firestore.runTransaction((transaction) async {
        // 1. Update status pembayaran jadi disetujui
        DocumentReference payRef = firestore
            .collection('pembayaran')
            .doc(docId);
        transaction.update(payRef, {'status': 'disetujui'});

        // 2. Tambahkan ke Transaksi Kas Global (Saldo Utama)
        DocumentReference transRef = firestore.collection('transactions').doc();
        transaction.set(transRef, {
          'keterangan':
              'Iuran Kas: ${data['nama_pengirim']} (${data['bulan']})',
          'jumlah': data['jumlah'],
          'type': 'masuk',
          'date': FieldValue.serverTimestamp(),
        });
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pembayaran Berhasil Diverifikasi!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _prosesTolak(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('pembayaran').doc(docId).update(
      {'status': 'ditolak'},
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Pembayaran telah ditolak."),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E), // Navy Theme
        title: const Text(
          "Verifikasi Pembayaran",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Header
          Container(
            height: 100,
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
                .collection('pembayaran')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  String docId = doc.id;
                  String base64Photo = data['url_bukti'] ?? "";

                  return _buildVerifCard(context, docId, data, base64Photo);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // WIDGET CARD VERIFIKASI PREMIUM
  Widget _buildVerifCard(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
    String photo,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card (Profil Pengirim)
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.indigo[50],
                  child: const Icon(Icons.person, color: Color(0xFF1A237E)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['nama_pengirim'] ?? "Anggota",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        "Periode: ${data['bulan']}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "PENDING",
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Foto Bukti Transfer (Optimized)
          GestureDetector(
            onTap: () => _showImagePreview(context, photo),
            child: Container(
              height: 200, width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
              clipBehavior: Clip.antiAlias,
              child: photo.isNotEmpty 
                ? Image.memory(
                    base64Decode(photo), 
                    fit: BoxFit.cover,
                    cacheWidth: 400, // PENTING: Optimasi RAM
                  )
                : const Center(child: Icon(Icons.image_not_supported)),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              "Klik gambar untuk memperbesar bukti transfer",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),

          // Info Nominal
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total Pembayaran:",
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Text(
                  formatCurrency((data['jumlah'] ?? 0).toDouble()),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 30),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _prosesTolak(context, id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text(
                      "TOLAK",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _prosesTerima(context, id, data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0,
                    ),
                    child: const Text(
                      "TERIMA",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          const Text(
            "Semua pembayaran sudah diverifikasi",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
