import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';

class VerifikasiBayarPage extends StatelessWidget {
  const VerifikasiBayarPage({super.key});

  Future<void> _prosesTerima(BuildContext context, String docId, Map<String, dynamic> data) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      await firestore.runTransaction((transaction) async {
        // 1. Update status pembayaran jadi disetujui
        DocumentReference payRef = firestore.collection('pembayaran').doc(docId);
        transaction.update(payRef, {'status': 'disetujui'});

        // 2. Tambahkan ke Transaksi Kas Global (Saldo)
        DocumentReference transRef = firestore.collection('transactions').doc();
        transaction.set(transRef, {
          'keterangan': 'Kas Masuk: ${data['nama_pengirim']} (${data['bulan']})',
          'jumlah': data['jumlah'],
          'type': 'masuk',
          'date': FieldValue.serverTimestamp(),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pembayaran Disetujui!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _prosesTolak(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('pembayaran').doc(docId).update({
      'status': 'ditolak'
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pembayaran Ditolak.")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verifikasi Pembayaran"), backgroundColor: Colors.teal),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pembayaran')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Tidak ada pembayaran pending."));
          }
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(data['nama_pengirim']),
                      subtitle: Text("Bulan: ${data['bulan']} - Rp ${data['jumlah']}"),
                    ),
                    Image.memory(base64Decode(data['url_bukti']), height: 200),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(onPressed: () => _prosesTolak(context, doc.id), child: const Text("TOLAK", style: TextStyle(color: Colors.red))),
                        ElevatedButton(onPressed: () => _prosesTerima(context, doc.id, data), child: const Text("TERIMA")),
                      ],
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}