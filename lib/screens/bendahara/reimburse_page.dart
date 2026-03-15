import 'dart:convert'; // Penting untuk base64Decode
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReimbursePage extends StatelessWidget {
  const ReimbursePage({super.key});

  // Fungsi untuk menampilkan foto ukuran penuh
  void _showImagePreview(BuildContext context, String base64String) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text("Bukti Nota", style: TextStyle(fontSize: 16)),
              automaticallyImplyLeading: false,
              actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))],
            ),
            InteractiveViewer( // Supaya gambar bisa di-zoom
              child: Image.memory(
                base64Decode(base64String),
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ceklis Reimburse"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reimbursements')
            .orderBy('tanggal_kirim', descending: true) // Urutkan dari yang terbaru
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("Belum ada pengajuan."));

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String docId = docs[index].id;
              bool isPaid = data['status'] == 'dibayar';
              String? base64Photo = data['url_bukti'];

              return Container(
                color: isPaid ? Colors.green[50] : Colors.white,
                child: ListTile(
                  leading: GestureDetector(
                    onTap: () {
                      if (base64Photo != null) _showImagePreview(context, base64Photo);
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: base64Photo != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(base64Decode(base64Photo), fit: BoxFit.cover),
                            )
                          : const Icon(Icons.image_not_supported),
                    ),
                  ),
                  title: Text(
                    data['nama_pengaju'] ?? "Tanpa Nama",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Rp ${data['jumlah']} - ${data['keperluan']}"),
                      const Text("Klik foto untuk memperbesar", style: TextStyle(fontSize: 10, color: Colors.blue)),
                    ],
                  ),
                  trailing: Checkbox(
                    value: isPaid,
                    onChanged: (val) {
                      FirebaseFirestore.instance
                          .collection('reimbursements')
                          .doc(docId)
                          .update({'status': val! ? 'dibayar' : 'pending'});
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}