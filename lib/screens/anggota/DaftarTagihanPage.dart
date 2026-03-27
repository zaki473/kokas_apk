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

  String _formatCurrency(int value) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        title: const Text("Tagihan Kas Saya", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Navy Header Background
          Container(
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
          ),
          
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('kas_deadline').orderBy('tanggal_deadline', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("Tidak ada daftar tagihan aktif.", style: TextStyle(color: Colors.white70)));
              }
              
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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

                      // Jika sudah lunas (disetujui), kita sembunyikan dari daftar tagihan
                      if (status == "disetujui") return const SizedBox.shrink();

                      return _buildTagihanCard(context, bulan, nominal, deadline, status);
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTagihanCard(BuildContext context, String bulan, int nominal, DateTime deadline, String status) {
    bool isExpired = DateTime.now().isAfter(deadline);
    
    // Tampilan Status UI
    Color statusColor = isExpired ? Colors.red : Colors.green;
    String statusLabel = isExpired ? "MELEWATI DEADLINE" : "AKTIF";
    IconData statusIcon = isExpired ? Icons.warning_amber_rounded : Icons.timer_outlined;

    if (status == "pending") {
      statusColor = Colors.orange;
      statusLabel = "VERIFIKASI";
      statusIcon = Icons.hourglass_top_rounded;
    } else if (status == "ditolak") {
      statusColor = Colors.redAccent;
      statusLabel = "DITOLAK / REVISI";
      statusIcon = Icons.error_outline_rounded;
    }

    return GestureDetector(
      onTap: (status == "pending") ? null : () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => 
          BayarKasPage(bulanTagihan: bulan, nominalTagihan: nominal)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text("Kas Bulan $bulan", 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 5),
                      Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                    ],
                  ),
                )
              ],
            ),
            const Divider(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Nominal", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(_formatCurrency(nominal), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1A237E))),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Batas Waktu", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(DateFormat('dd MMM yyyy').format(deadline), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- HALAMAN BAYAR KAS (UI BARU DENGAN LOADING HORIZONTAL) ---
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bukti berhasil dikirim! Menunggu verifikasi."),
          backgroundColor: Colors.indigo,
          behavior: SnackBarBehavior.floating,
        )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedPrice = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(widget.nominalTagihan);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        title: Text("Bayar Kas ${widget.bulanTagihan}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Container(
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total Tagihan:", style: TextStyle(fontSize: 14, color: Colors.grey)),
                      Text(formattedPrice, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A237E))),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const Text("Bukti Transfer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                const SizedBox(height: 15),
                
                // Upload Bukti
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 20);
                    if (img != null) {
                      List<int> bytes = await File(img.path).readAsBytes();
                      setState(() => _base64Image = base64Encode(bytes));
                    }
                  },
                  child: Container(
                    height: 280, 
                    width: double.infinity, 
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _base64Image == null 
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center, 
                          children: [
                            Icon(Icons.add_a_photo_rounded, size: 50, color: Colors.grey),
                            SizedBox(height: 10),
                            Text("Klik untuk Upload Bukti", style: TextStyle(color: Colors.grey))
                          ]) 
                      : Image.memory(base64Decode(_base64Image!), fit: BoxFit.cover, cacheWidth: 600),
                  ),
                ),
                const SizedBox(height: 40),
                
                // Loading Horizontal Navy
                if (_isUploading)
                  Column(
                    children: [
                      const Text("Mengirim data...", style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: const LinearProgressIndicator(
                          minHeight: 6,
                          backgroundColor: Colors.white,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E), 
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 5,
                        shadowColor: const Color(0xFF1A237E).withOpacity(0.4),
                      ),
                      onPressed: _kirimPembayaran,
                      child: const Text("KIRIM KONFIRMASI PEMBAYARAN", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }
}