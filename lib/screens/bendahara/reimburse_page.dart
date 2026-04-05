import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/error_service.dart';

class ReimbursePage extends StatefulWidget {
  const ReimbursePage({super.key});

  @override
  State<ReimbursePage> createState() => _ReimbursePageState();
}

class _ReimbursePageState extends State<ReimbursePage> {
  final Color primaryNavy = const Color(0xFF1A237E);
  final Color backgroundColor = const Color(0xFFF4F6F8);

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
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryNavy,
        title: const Text(
          "Verifikasi Reimburse",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingGroup
          ? Center(child: CircularProgressIndicator(color: primaryNavy))
          : _groupId == null || _groupId!.isEmpty
              ? _buildNoGroupState()
              : Stack(
                  children:[
                    // Background atas biru
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: primaryNavy,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                      ),
                    ),
                    
                    StreamBuilder<QuerySnapshot>(
                      // OPTIMASI: Gunakan limit untuk mencegah memori penuh
                      stream: FirebaseFirestore.instance
                          .collection('reimbursements')
                          .where('groupId', isEqualTo: _groupId)
                          .orderBy('tanggal_kirim', descending: true)
                          .limit(50)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _buildErrorState(snapshot.error.toString());
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.white));
                        }

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return _buildEmptyState();
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
                              primaryNavy: primaryNavy,
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
    );
  }

  Widget _buildNoGroupState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children:[
          Icon(Icons.group_off_rounded, size: 80, color: Colors.grey),
          SizedBox(height: 15),
          Text(
            "Anda tidak terhubung dengan grup kas mana pun.",
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children:[
          Icon(Icons.request_quote_rounded, size: 80, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 15),
          const Text(
            "Belum ada pengajuan reimburse.",
            style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children:[
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
            const SizedBox(height: 15),
            const Text("Oops! Terjadi kesalahan.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              error.contains("index") 
                ? "Database memerlukan sinkronisasi indeks. Silakan hubungi pengembang." 
                : "Gagal memuat data.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class ReimburseCardItem extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  final Map<String, Uint8List> imageCache;
  final Color primaryNavy;

  const ReimburseCardItem({
    super.key,
    required this.id,
    required this.data,
    required this.imageCache,
    required this.primaryNavy,
  });

  @override
  State<ReimburseCardItem> createState() => _ReimburseCardItemState();
}

class _ReimburseCardItemState extends State<ReimburseCardItem> {
  bool _isUpdating = false;

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  // 🔥 FUNGSI YANG DIUBAH MENGGUNAKAN ERROR SERVICE
  Future<void> _handleStatusChange(bool val) async {
    if (_isUpdating) return; // Mencegah klik ganda

    setState(() => _isUpdating = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('reimbursements')
          .doc(widget.id)
          .update({'status': val ? 'dibayar' : 'pending'});

      // Matikan indikator loading SEBELUM memunculkan Pop-Up
      if (mounted) setState(() => _isUpdating = false);

      if (mounted) {
        // Panggil Pop-Up Sukses
        await ErrorService.showSuccess(
          context, 
          val ? "Mantap! Pengajuan Reimburse telah ditandai sebagai LUNAS." 
              : "Status pengajuan telah dikembalikan menjadi Pending."
        );
      }
    } catch (e) {
      // Matikan indikator loading SEBELUM memunculkan Pop-Up Error
      if (mounted) setState(() => _isUpdating = false);
      
      if (mounted) {
        // Panggil Pop-Up Error
        ErrorService.show(context, e);
      }
    }
  }

  void _showImagePreview(BuildContext context, Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions:[
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
        body: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4,
            child: Image.memory(imageBytes),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isPaid = widget.data['status'] == 'dibayar';
    String? photoBase64 = widget.data['url_bukti'];

    // Decode Base64 dengan caching & try-catch (Anti crash jika string corrupt)
    Uint8List? imageBytes;
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      if (widget.imageCache.containsKey(photoBase64)) {
        imageBytes = widget.imageCache[photoBase64];
      } else {
        try {
          imageBytes = base64Decode(photoBase64);
          widget.imageCache[photoBase64] = imageBytes;
        } catch (e) {
          debugPrint("Error decoding base64 image: $e");
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green[50]?.withValues(alpha: 0.4) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: isPaid ? Border.all(color: Colors.green.withValues(alpha: 0.3)) : null,
        boxShadow:[
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children:[
          // 1. Gambar Bukti
          GestureDetector(
            onTap: () {
              if (imageBytes != null) _showImagePreview(context, imageBytes);
            },
            child: Container(
              width: 65, 
              height: 65,
              decoration: BoxDecoration(
                color: Colors.grey[100], 
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200)
              ),
              clipBehavior: Clip.antiAlias,
              child: imageBytes != null
                  ? Image.memory(imageBytes, fit: BoxFit.cover)
                  : const Center(child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 28)),
            ),
          ),
          const SizedBox(width: 15),
          
          // 2. Info Teks (Expanded agar aman dari overflow)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                Text(
                  widget.data['nama_pengaju'] ?? "Anggota",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3142)),
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatCurrency((widget.data['jumlah'] ?? 0).toDouble()),
                    style: TextStyle(fontWeight: FontWeight.w900, color: widget.primaryNavy, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.data['keperluan'] ?? "-",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          
          // 3. Tombol Checkbox & Status
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children:[
              SizedBox(
                height: 32, 
                width: 32,
                child: _isUpdating
                    ? const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.green),
                      )
                    : Transform.scale(
                        scale: 1.2,
                        child: Checkbox(
                          value: isPaid,
                          activeColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) => _handleStatusChange(val ?? false),
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                isPaid ? "LUNAS" : "BAYAR",
                style: TextStyle(
                  fontSize: 10, 
                  fontWeight: FontWeight.w800, 
                  color: isPaid ? Colors.green : Colors.grey[500],
                  letterSpacing: 0.5
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}