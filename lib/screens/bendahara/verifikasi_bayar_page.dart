import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class VerifikasiBayarPage extends StatefulWidget {
  const VerifikasiBayarPage({super.key});

  @override
  State<VerifikasiBayarPage> createState() => _VerifikasiBayarPageState();
}

class _VerifikasiBayarPageState extends State<VerifikasiBayarPage> {
  String? _bendaharaGroupId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTreasurerData();
  }

  Future<void> _loadTreasurerData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _bendaharaGroupId = userDoc.get('groupId'); 
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  Future<void> _prosesTerima(BuildContext context, String docId, Map<String, dynamic> data) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      final firestore = FirebaseFirestore.instance;
      String gId = data['groupId'] ?? ""; 

      if (gId.isEmpty) {
        Navigator.pop(context);
        _showSnackBar("Gagal: Data pembayaran tidak memiliki groupId!", Colors.red);
        return;
      }

      int nominal = (data['jumlah'] is num) ? (data['jumlah'] as num).toInt() : 0;

      await firestore.runTransaction((transaction) async {
        transaction.update(firestore.collection('pembayaran').doc(docId), {'status': 'disetujui'});

        DocumentReference transRef = firestore.collection('transactions').doc();
        transaction.set(transRef, {
          'date': FieldValue.serverTimestamp(),
          'groupId': gId, 
          'jumlah': nominal,
          'keterangan': 'Iuran: ${data['nama_pengirim']} (${data['bulan']})',
          'type': 'masuk',
        });
      });

      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar("Pembayaran berhasil diverifikasi!", Colors.green);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar("Error: $e", Colors.red);
    }
  }

  Future<void> _prosesTolak(String docId) async {
    await FirebaseFirestore.instance.collection('pembayaran').doc(docId).update({'status': 'ditolak'});
    _showSnackBar("Pembayaran ditolak.", Colors.redAccent);
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  // 🔥 FUNGSI BARU UNTUK ZOOM GAMBAR
  void _showZoomImage(BuildContext context, String base64Photo) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // InteractiveViewer memungkinkan cubit-zoom (pinch style)
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.memory(
                  base64Decode(base64Photo),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Tombol Close
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
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
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        title: const Text("Verifikasi Pembayaran", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
      ? const Center(child: CircularProgressIndicator())
      : Stack(
          children: [
            Container(height: 80, decoration: const BoxDecoration(color: Color(0xFF1A237E), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)))),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pembayaran')
                  .where('status', isEqualTo: 'pending')
                  .where('groupId', isEqualTo: _bendaharaGroupId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Tidak ada pembayaran pending"));

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    return _buildVerifCard(doc.id, data);
                  },
                );
              },
            ),
          ],
        ),
    );
  }

  Widget _buildVerifCard(String id, Map<String, dynamic> data) {
    String photo = data['url_bukti'] ?? "";
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(backgroundColor: Color(0xFF1A237E), child: Icon(Icons.person, color: Colors.white)),
            title: Text(data['nama_pengirim'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Iuran Bulan: ${data['bulan']}"),
            trailing: Text(formatCurrency((data['jumlah'] ?? 0).toDouble()), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
          ),
          const SizedBox(height: 10),
          
          if (photo.isNotEmpty) 
            GestureDetector(
              onTap: () => _showZoomImage(context, photo), // Tap untuk memperbesar
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(base64Decode(photo), height: 150, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => _prosesTolak(id), style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text("TOLAK"))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(onPressed: () => _prosesTerima(context, id, data), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("TERIMA", style: TextStyle(color: Colors.white)))),
            ],
          )
        ],
      ),
    );
  }
}