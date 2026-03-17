import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class DaftarTagihanPage extends StatefulWidget {
  const DaftarTagihanPage({super.key});

  @override
  State<DaftarTagihanPage> createState() => _DaftarTagihanPageState();
}

class _DaftarTagihanPageState extends State<DaftarTagihanPage> {
  final String currentUserUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tagihan Kas Saya"), 
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('kas_deadline').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var tagihan = snapshot.data!.docs[index];
              String bulan = tagihan['bulan'];
              int nominal = tagihan['nominal'];
              DateTime deadline = (tagihan['tanggal_deadline'] as Timestamp).toDate();

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('pembayaran')
                    .where('uid_pengirim', isEqualTo: currentUserUid)
                    .where('bulan', isEqualTo: bulan)
                    .snapshots(),
                builder: (context, paySnapshot) {
                  String status = "belum_bayar";
                  if (paySnapshot.hasData && paySnapshot.data!.docs.isNotEmpty) {
                    status = paySnapshot.data!.docs.first['status'];
                  }

                  if (status == "disetujui") return const SizedBox.shrink();

                  bool isExpired = DateTime.now().isAfter(deadline);
                  Color boxColor = isExpired ? Colors.red[50]! : Colors.green[50]!;
                  Color borderColor = isExpired ? Colors.red : Colors.green;
                  String statusText = isExpired ? "Melewati Deadline" : "Aktif";
                  
                  if (status == "pending") {
                    boxColor = Colors.orange[50]!;
                    borderColor = Colors.orange;
                    statusText = "Menunggu Verifikasi";
                  } else if (status == "ditolak") {
                    boxColor = Colors.red[100]!;
                    borderColor = Colors.red;
                    statusText = "Ditolak (Bayar Ulang)";
                  }

                  return GestureDetector(
                    onTap: (status == "pending") ? null : () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => 
                        BayarKasPage(bulanTagihan: bulan, nominalTagihan: nominal)));
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: boxColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start, // Agar text panjang rapi dari atas
                            children: [
                              // MENGGUNAKAN EXPANDED AGAR TEXT BULAN BISA WRAP (TURUN KE BAWAH)
                              Expanded(
                                child: Text(
                                  "Kas Bulan $bulan", 
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                  softWrap: true,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Status tetap di kanan
                              Text(
                                statusText, 
                                style: TextStyle(fontWeight: FontWeight.bold, color: borderColor, fontSize: 13),
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Nominal: Rp ${NumberFormat('#,###').format(nominal)}", style: const TextStyle(fontSize: 14)),
                              Text(
                                DateFormat('dd MMM yyyy').format(deadline),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class BayarKasPage extends StatefulWidget {
  final String bulanTagihan;
  final int nominalTagihan;
  const BayarKasPage({super.key, required this.bulanTagihan, required this.nominalTagihan});

  @override
  State<BayarKasPage> createState() => _BayarKasPageState();
}

class _BayarKasPageState extends State<BayarKasPage> {
  String? _base64Image;
  bool _isUploading = false;

  void _kirimPembayaran() async {
    if (_base64Image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih foto bukti terlebih dahulu!")));
      return;
    }
    
    setState(() => _isUploading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String docId = "${user.uid}_${widget.bulanTagihan}";
      
      // Menggunakan .set dengan merge: true agar jika dokumen sudah ada (ditolak), data lama tertimpa
      await FirebaseFirestore.instance.collection('pembayaran').doc(docId).set({
        'uid_pengirim': user.uid,
        'nama_pengirim': user.email,
        'jumlah': widget.nominalTagihan,
        'bulan': widget.bulanTagihan,
        'url_bukti': _base64Image,
        'status': 'pending',
        'tanggal_kirim': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bukti berhasil dikirim ulang!")));
    } catch (e) {
      // Jika masih Permission Denied, berarti Rules di Firebase belum diupdate
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bayar Kas ${widget.bulanTagihan}")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Bayar:", style: TextStyle(fontSize: 16)),
                  Text("Rp ${NumberFormat('#,###').format(widget.nominalTagihan)}", 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            GestureDetector(
              onTap: () async {
                final picker = ImagePicker();
                final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 20); // Perkecil kualitas agar tidak lambat
                if (img != null) {
                  List<int> bytes = await File(img.path).readAsBytes();
                  setState(() => _base64Image = base64Encode(bytes));
                }
              },
              child: Container(
                height: 250, 
                width: double.infinity, 
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: _base64Image == null 
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [Icon(Icons.add_a_photo, size: 50, color: Colors.grey), Text("Klik untuk Upload Bukti")]) 
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.memory(base64Decode(_base64Image!), fit: BoxFit.cover),
                    ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
                onPressed: _isUploading ? null : _kirimPembayaran,
                child: _isUploading ? const CircularProgressIndicator(color: Colors.white) : const Text("KIRIM BUKTI PEMBAYARAN"),
              ),
            )
          ],
        ),
      ),
    );
  }
}