import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '/services/error_service.dart';

class VerifikasiBayarPage extends StatefulWidget {
  const VerifikasiBayarPage({super.key});

  @override
  State<VerifikasiBayarPage> createState() => _VerifikasiBayarPageState();
}

class _VerifikasiBayarPageState extends State<VerifikasiBayarPage> {
  String? _bendaharaGroupId;
  bool _isLoading = true;
  final Map<String, Uint8List> _imageCache = {};

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

        if (userDoc.exists && mounted) {
          setState(() {
            _bendaharaGroupId = userDoc.get('groupId');
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorService.show(context, e);
        setState(() => _isLoading = false);
      }
    }
  }

  String formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope( // Ganti WillPopScope yang deprecated
        canPop: false,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }

  Future<void> _prosesTerima(BuildContext context, String docId, Map<String, dynamic> data) async {
    _showLoadingDialog();

    try {
      final firestore = FirebaseFirestore.instance;
      String gId = data['groupId'] ?? "";
      int nominal = (data['jumlah'] is num) ? (data['jumlah'] as num).toInt() : 0;

      await firestore.runTransaction((transaction) async {
        // Update status pembayaran
        transaction.update(firestore.collection('pembayaran').doc(docId), {
          'status': 'disetujui',
          'verified_at': FieldValue.serverTimestamp(),
        });

        // Catat sebagai pemasukan resmi di kas grup
        DocumentReference transRef = firestore.collection('transactions').doc();
        transaction.set(transRef, {
          'date': FieldValue.serverTimestamp(),
          'groupId': gId,
          'jumlah': nominal,
          'keterangan': 'Iuran: ${data['nama_pengirim']} (${data['bulan']})',
          'type': 'masuk',
          'source': 'payment_verification', // Metadata tambahan
        });
      });

      if (!mounted) return;
      Navigator.pop(context); // Tutup loading
      ErrorService.showSuccess(context, "Verifikasi Berhasil!");
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ErrorService.show(context, e);
      }
    }
  }

  Future<void> _prosesTolak(String docId) async {
    _showLoadingDialog();
    try {
      await FirebaseFirestore.instance.collection('pembayaran').doc(docId).update({
        'status': 'ditolak',
        'rejected_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pembayaran telah ditolak"), backgroundColor: Colors.redAccent)
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ErrorService.show(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        title: const Text("Verifikasi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A237E),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('pembayaran')
                        .where('status', isEqualTo: 'pending')
                        .where('groupId', isEqualTo: _bendaharaGroupId)
                        .orderBy('tanggal_kirim', descending: false) // List tertua di atas (antrian)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      var docs = snapshot.data!.docs;
                      if (docs.isEmpty) return _buildEmptyState();

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var data = docs[index].data() as Map<String, dynamic>;
                          return _buildVerifCard(docs[index].id, data);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVerifCard(String id, Map<String, dynamic> data) {
    String photoBase64 = data['url_bukti'] ?? "";
    Uint8List? imageBytes = photoBase64.isNotEmpty 
        ? _imageCache.putIfAbsent(photoBase64, () => base64Decode(photoBase64))
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(15),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1A237E).withOpacity(0.1),
              child: const Icon(Icons.person_outline, color: Color(0xFF1A237E)),
            ),
            title: Text(data['nama_pengirim'] ?? "Anggota", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text("Iuran ${data['bulan']}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatCurrency((data['jumlah'] ?? 0).toDouble()), 
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 15)),
                const Text("Menunggu", style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (imageBytes != null)
            GestureDetector(
              onTap: () => _showZoomImage(context, imageBytes),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 15),
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: DecorationImage(
                    image: MemoryImage(imageBytes),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                    ),
                  ),
                  child: const Icon(Icons.fullscreen, color: Colors.white),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _prosesTolak(id),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text("TOLAK", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _prosesTerima(context, id, data),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text("TERIMA", style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_outlined, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text("Semua beres!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          Text("Tidak ada antrian verifikasi.", style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }

  // Fungsi Zoom tetap sama (sudah bagus)
  void _showZoomImage(BuildContext context, Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.memory(imageBytes, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 20, right: 20,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}