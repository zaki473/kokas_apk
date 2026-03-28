import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReimbursePage extends StatelessWidget {
  const ReimbursePage({super.key});

  @override
  Widget build(BuildContext context) {
    // PERHATIAN: Jika ini akun Anggota, myUid adalah ID Anggota.
    // Pastikan di Firestore field 'groupId' berisi ID ini. 
    // Jika sistemnya Anggota bergabung ke grup Bendahara, 
    // Anda harus mengambil groupId dari profile user dulu.
    final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        title: const Text(
          "Ceklis Reimburse",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
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
            // MENGHAPUS .orderBy AGAR TIDAK BUTUH INDEXING
            stream: FirebaseFirestore.instance
                .collection('reimbursements')
                .where('groupId', isEqualTo: myUid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Ambil dokumen
              List<QueryDocumentSnapshot> docs = snapshot.data?.docs ?? [];
              
              if (docs.isEmpty) {
                return const Center(
                  child: Text("Belum ada pengajuan.", style: TextStyle(color: Color.fromARGB(255, 0, 0, 0))),
                );
              }

              // --- PROSES SORTIR MANUAL (Terbaru di atas) ---
              docs.sort((a, b) {
                var dataA = a.data() as Map<String, dynamic>;
                var dataB = b.data() as Map<String, dynamic>;
                Timestamp tA = dataA['tanggal_kirim'] ?? Timestamp.now();
                Timestamp tB = dataB['tanggal_kirim'] ?? Timestamp.now();
                return tB.compareTo(tA);
              });

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  return ReimburseCardItem(id: docs[index].id, data: data);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class ReimburseCardItem extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;

  const ReimburseCardItem({super.key, required this.id, required this.data});

  @override
  State<ReimburseCardItem> createState() => _ReimburseCardItemState();
}

class _ReimburseCardItemState extends State<ReimburseCardItem> {
  bool _isUpdating = false;

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  void _showImagePreview(BuildContext context, String base64String) {
    if (base64String.isEmpty) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Close",
      barrierColor: Colors.black.withOpacity(0.9),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    child: Image.memory(
                      base64Decode(base64String),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 35),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isPaid = widget.data['status'] == 'dibayar';
    String? photo = widget.data['url_bukti'];

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green[50]?.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () { if (photo != null) _showImagePreview(context, photo); },
              child: Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)),
                clipBehavior: Clip.antiAlias,
                child: photo != null
                    ? Image.memory(base64Decode(photo), fit: BoxFit.cover)
                    : const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.data['nama_pengaju'] ?? "Anggota", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(_formatCurrency((widget.data['jumlah'] ?? 0).toDouble()), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A237E))),
                  Text(widget.data['keperluan'] ?? "-", style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
              children: [
                SizedBox(
                  height: 40, width: 40,
                  child: _isUpdating
                      ? const Padding(padding: EdgeInsets.all(10.0), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                      : Checkbox(
                          value: isPaid,
                          activeColor: Colors.green,
                          onChanged: (val) async {
                            setState(() => _isUpdating = true);
                            try {
                              await FirebaseFirestore.instance
                                  .collection('reimbursements')
                                  .doc(widget.id)
                                  .update({'status': val! ? 'dibayar' : 'pending'});
                            } finally {
                              if (mounted) setState(() => _isUpdating = false);
                            }
                          },
                        ),
                ),
                Text(isPaid ? "LUNAS" : "BAYAR", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isPaid ? Colors.green : Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}