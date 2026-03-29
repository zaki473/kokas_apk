import 'dart:convert';
import 'dart:typed_data'; // Tambahan untuk efisiensi memory
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '/services/error_service.dart'; // Pastikan path ini benar

class VerifikasiBayarPage extends StatefulWidget {
  const VerifikasiBayarPage({super.key});

  @override
  State<VerifikasiBayarPage> createState() => _VerifikasiBayarPageState();
}

class _VerifikasiBayarPageState extends State<VerifikasiBayarPage> {
  String? _bendaharaGroupId;
  bool _isLoading = true;
  // Cache untuk menyimpan bytes gambar agar tidak decode berulang-ulang
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
      if (!context.mounted) return;
      ErrorService.show(context, e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  // Helper untuk loading dialog agar tidak duplikasi code
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  Future<void> _prosesTerima(BuildContext context, String docId, Map<String, dynamic> data) async {
    _showLoadingDialog();

    try {
      final firestore = FirebaseFirestore.instance;
      String gId = data['groupId'] ?? "";

      if (gId.isEmpty) {
        Navigator.pop(context);
        _showSnackBar("Gagal: Data tidak valid!", Colors.red);
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

      if (!context.mounted) return;
      Navigator.pop(context);
      ErrorService.showSuccess(context, "Pembayaran berhasil diverifikasi!");
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ErrorService.show(context, e);
    }
  }

  Future<void> _prosesTolak(String docId) async {
    _showLoadingDialog(); // Tambahkan loading agar user tidak klik berkali-kali
    try {
      await FirebaseFirestore.instance.collection('pembayaran').doc(docId).update({'status': 'ditolak'});
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar("Pembayaran ditolak.", Colors.redAccent);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar("Gagal menolak data", Colors.red);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

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
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.memory(imageBytes, fit: BoxFit.contain),
              ),
            ),
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
                Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A237E),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                  ),
                ),
                if (_bendaharaGroupId == null)
                  const Center(child: Text("Gagal mengambil data grup"))
                else
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('pembayaran')
                        .where('status', isEqualTo: 'pending')
                        .where('groupId', isEqualTo: _bendaharaGroupId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("Tidak ada pembayaran pending"));
                      }

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
    String photoBase64 = data['url_bukti'] ?? "";
    
    // Logic Caching Image: Supaya tidak decode Base64 berulang-ulang saat scroll
    Uint8List? imageBytes;
    if (photoBase64.isNotEmpty) {
      if (_imageCache.containsKey(photoBase64)) {
        imageBytes = _imageCache[photoBase64];
      } else {
        imageBytes = base64Decode(photoBase64);
        _imageCache[photoBase64] = imageBytes;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(backgroundColor: Color(0xFF1A237E), child: Icon(Icons.person, color: Colors.white)),
            title: Text(data['nama_pengirim'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Iuran Bulan: ${data['bulan']}"),
            trailing: Text(
              formatCurrency((data['jumlah'] ?? 0).toDouble()),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
            ),
          ),
          const SizedBox(height: 10),
          if (imageBytes != null)
            GestureDetector(
              onTap: () => _showZoomImage(context, imageBytes!),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      imageBytes,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      // Tambahkan cacheHeight untuk mengurangi beban memori
                      cacheHeight: 400, 
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _prosesTolak(id),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text("TOLAK"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _prosesTerima(context, id, data),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("TERIMA", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}