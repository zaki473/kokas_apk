import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReimbursePage extends StatefulWidget {
  const ReimbursePage({super.key});

  @override
  State<ReimbursePage> createState() => _ReimbursePageState();
}

class _ReimbursePageState extends State<ReimbursePage> {
  String? _groupId;
  bool _isLoadingGroup = true;
  // Cache untuk gambar agar tidak lag saat scroll
  final Map<String, Uint8List> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _loadGroupId();
  }

  Future<void> _loadGroupId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (mounted) {
          setState(() {
            _groupId = doc.data()?['groupId'];
            _isLoadingGroup = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingGroup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        title: const Text(
          "Verifikasi Reimburse",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingGroup
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)))
          : Stack(
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
                  // OPTIMASI QA: Gunakan orderBy di Firestore agar HP tidak kerja berat menyortir data
                  stream: FirebaseFirestore.instance
                      .collection('reimbursements')
                      .where('groupId', isEqualTo: _groupId)
                      .orderBy('tanggal_kirim', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: Pastikan index sudah dibuat."));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text("Belum ada pengajuan reimburse.",
                            style: TextStyle(color: Colors.grey)),
                      );
                    }

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        return ReimburseCardItem(
                          id: docs[index].id,
                          data: data,
                          imageCache: _imageCache,
                        );
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
  final Map<String, Uint8List> imageCache;

  const ReimburseCardItem({
    super.key,
    required this.id,
    required this.data,
    required this.imageCache,
  });

  @override
  State<ReimburseCardItem> createState() => _ReimburseCardItemState();
}

class _ReimburseCardItemState extends State<ReimburseCardItem> {
  bool _isUpdating = false;

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  // FUNGSI: Hanya ubah status, tidak input ke transaksi otomatis
  Future<void> _handleStatusChange(bool val) async {
    setState(() => _isUpdating = true);
    
    try {
      // HANYA UPDATE STATUS DI DOKUMEN REIMBURSE
      await FirebaseFirestore.instance
          .collection('reimbursements')
          .doc(widget.id)
          .update({'status': val ? 'dibayar' : 'pending'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(val ? "Ditandai sebagai Lunas" : "Status dikembalikan ke Pending"),
            backgroundColor: val ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal update status: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showImagePreview(BuildContext context, Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: InteractiveViewer(child: Image.memory(imageBytes)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isPaid = widget.data['status'] == 'dibayar';
    String? photoBase64 = widget.data['url_bukti'];

    // Decode Base64 dengan caching agar scroll lancar
    Uint8List? imageBytes;
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      if (widget.imageCache.containsKey(photoBase64)) {
        imageBytes = widget.imageCache[photoBase64];
      } else {
        imageBytes = base64Decode(photoBase64);
        widget.imageCache[photoBase64] = imageBytes;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green[50]?.withValues(alpha: 0.4) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: GestureDetector(
          onTap: () {
            if (imageBytes != null) _showImagePreview(context, imageBytes);
          },
          child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: imageBytes != null
                ? Image.memory(imageBytes, fit: BoxFit.cover)
                : const Icon(Icons.image_not_supported, color: Colors.grey),
          ),
        ),
        title: Text(
          widget.data['nama_pengaju'] ?? "Anggota",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatCurrency((widget.data['jumlah'] ?? 0).toDouble()),
              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A237E), fontSize: 14),
            ),
            Text(
              widget.data['keperluan'] ?? "-",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 24, width: 24,
              child: _isUpdating
                  ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.green)
                  : Checkbox(
                      value: isPaid,
                      activeColor: Colors.green,
                      onChanged: (val) => _handleStatusChange(val ?? false),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              isPaid ? "LUNAS" : "BAYAR",
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isPaid ? Colors.green : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}