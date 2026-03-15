import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class VerifikasiBayarPage extends StatelessWidget {
  const VerifikasiBayarPage({super.key});

  // --- FUNGSI PROSES TERIMA PEMBAYARAN (DENGAN LOGIKA CICILAN) ---
  Future<void> _prosesTerima(BuildContext context, String docId, Map<String, dynamic> data) async {
    final firestore = FirebaseFirestore.instance;
    
    // Ambil info dari data pembayaran yang dikirim anggota
    final String userId = data['uid_pengirim']; // Pastikan saat anggota bayar, simpan UID-nya
    final String bulanTagihan = data['bulan']; 
    final int jumlahBayar = data['jumlah'];

    try {
      await firestore.runTransaction((transaction) async {
        // 1. Cari data di koleksi 'tagihan' yang sesuai dengan user dan bulannya
        QuerySnapshot tagihanQuery = await firestore
            .collection('tagihan')
            .where('uid', isEqualTo: userId)
            .where('bulan', isEqualTo: bulanTagihan)
            .limit(1)
            .get();

        if (tagihanQuery.docs.isEmpty) {
          throw "Data tagihan tidak ditemukan untuk bulan ini!";
        }

        DocumentReference tagihanRef = tagihanQuery.docs.first.reference;
        DocumentSnapshot tagihanSnap = tagihanQuery.docs.first;
        
        int sisaTagihanLama = tagihanSnap['sisa_tagihan'] ?? 0;
        int sisaTagihanBaru = sisaTagihanLama - jumlahBayar;

        // Validasi jika bayar kelebihan (opsional)
        if (sisaTagihanBaru < 0) sisaTagihanBaru = 0;

        // Tentukan status berdasarkan sisa
        String statusBaru = sisaTagihanBaru <= 0 ? 'lunas' : 'mencicil';

        // 2. Update status di koleksi 'pembayaran' (Bukti yang sedang dicek)
        DocumentReference payRef = firestore.collection('pembayaran').doc(docId);
        transaction.update(payRef, {'status': 'disetujui'});

        // 3. Update data di koleksi 'tagihan' (Mengurangi hutang)
        transaction.update(tagihanRef, {
          'sisa_tagihan': sisaTagihanBaru,
          'status': statusBaru,
          'terakhir_bayar': DateTime.now(),
        });

        // 4. Tambahkan ke rekap transaksi global (Saldo Kas)
        DocumentReference transRef = firestore.collection('transactions').doc();
        transaction.set(transRef, {
          'keterangan': 'Kas: ${data['nama_pengirim']} ($bulanTagihan)',
          'jumlah': jumlahBayar,
          'type': 'masuk',
          'date': DateTime.now(),
        });
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pembayaran Disetujui! Tagihan telah diperbarui."), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  // --- FUNGSI TOLAK PEMBAYARAN ---
  Future<void> _prosesTolak(BuildContext context, String docId) async {
    await FirebaseFirestore.instance.collection('pembayaran').doc(docId).update({
      'status': 'ditolak'
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Pembayaran ditolak."), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verifikasi Pembayaran"),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pembayaran')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("Semua pembayaran sudah diproses."),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              var docId = doc.id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(data['nama_pengirim']),
                      subtitle: Text("Bulan: ${data['bulan']}\nBayar: Rp ${data['jumlah']}"),
                      trailing: Text(
                        DateFormat('dd/MM HH:mm').format(data['tanggal_kirim'].toDate()),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    
                    // Bukti Gambar
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(child: Image.memory(base64Decode(data['url_bukti']))),
                        );
                      },
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 15),
                        color: Colors.grey[200],
                        child: Image.memory(base64Decode(data['url_bukti']), fit: BoxFit.contain),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              onPressed: () => _prosesTolak(context, docId),
                              child: const Text("TOLAK"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                              onPressed: () => _prosesTerima(context, docId, data),
                              child: const Text("TERIMA", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
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