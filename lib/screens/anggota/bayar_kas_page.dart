import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../image_helper.dart'; 
import '/services/error_service.dart';

class BayarKasPage extends StatefulWidget {
  final String bulan;
  final int nominal;
  final DateTime deadline;

  const BayarKasPage({
    super.key,
    required this.bulan,
    required this.nominal,
    required this.deadline,
  });

  @override
  State<BayarKasPage> createState() => _BayarKasPageState();
}

class _BayarKasPageState extends State<BayarKasPage> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController();
  final _bulanController = TextEditingController();

  String? _base64Image;
  Uint8List? _imageBytes;
  String? _myGroupId;
  bool _isUploading = false;

  Timer? _timer;
  DateTime _now = DateTime.now();

  final Color primaryNavy = const Color(0xFF1A237E);
  final Color backgroundColor = const Color(0xFFF4F6F8);

  @override
  void initState() {
    super.initState();
    _bulanController.text = widget.bulan;
    _jumlahController.text = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(widget.nominal);

    _loadUserGroupId();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _loadUserGroupId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && mounted) {
        setState(() => _myGroupId = userDoc['groupId']);
      }
    } catch (e) {
      debugPrint("Gagal load GroupID: $e");
    }
  }

  Future<void> _pickImage() async {
    String? img = await ImageHelper.pickAndCompress();
    if (img != null) {
      setState(() {
        _base64Image = img;
        _imageBytes = base64Decode(img);
      });
    }
  }

  void _kirimPembayaran() async {
    if (_base64Image == null) {
      _showSnackBar("Mohon lampirkan bukti transfer terlebih dahulu", Colors.orangeAccent);
      return;
    }

    if (_myGroupId == null || _myGroupId!.isEmpty) {
      _showSnackBar("Gagal mengidentifikasi grup Anda. Coba beberapa saat lagi.", Colors.red);
      _loadUserGroupId();
      return;
    }

    setState(() => _isUploading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser!;
      String docId = "${user.uid}_${widget.bulan}_${DateTime.now().millisecondsSinceEpoch}";

      await FirebaseFirestore.instance.collection('pembayaran').doc(docId).set({
        'uid_pengirim': user.uid,
        'nama_pengirim': user.displayName ?? user.email, 
        'jumlah': widget.nominal,
        'bulan': widget.bulan,
        'url_bukti': _base64Image, 
        'status': 'pending',
        'groupId': _myGroupId,
        'tanggal_kirim': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      // Mengasumsikan ErrorService punya method showSuccess
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Konfirmasi terkirim!"), backgroundColor: Colors.green)
      );
    } catch (e) {
      ErrorService.show(context, e);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg), 
        backgroundColor: color, 
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _jumlahController.dispose();
    _bulanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Duration sisa = widget.deadline.difference(_now);
    bool isExpired = _now.isAfter(widget.deadline);

    return PopScope(
      canPop: !_isUploading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showSnackBar("Mohon tunggu, sedang memproses...", Colors.orange);
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: primaryNavy,
          title: const Text("Konfirmasi Bayar", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            // Header Navy Background
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: primaryNavy,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30), 
                  bottomRight: Radius.circular(30)
                ),
              ),
            ),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _buildCountdownBox(isExpired, sisa),
                    const SizedBox(height: 25),
                    Text("Detail Tagihan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy)),
                    const SizedBox(height: 15),
                    _buildInputField(controller: _bulanController, label: "Bulan Iuran", icon: Icons.calendar_month_rounded),
                    const SizedBox(height: 15),
                    _buildInputField(controller: _jumlahController, label: "Total Tagihan", icon: Icons.account_balance_wallet_rounded),
                    const SizedBox(height: 25),
                    Text("Bukti Transfer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy)),
                    const SizedBox(height: 15),
                    _buildUploadBox(),
                    const SizedBox(height: 40),
                    _isUploading 
                      ? _buildHorizontalLoading()
                      : _buildSubmitButton(isExpired),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildCountdownBox(bool isExpired, Duration sisa) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isExpired ? Colors.red.withOpacity(0.1) : primaryNavy.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.timer_outlined, color: isExpired ? Colors.red : primaryNavy, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired ? "STATUS TAGIHAN" : "SISA WAKTU PEMBAYARAN",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  isExpired 
                    ? "Masa pembayaran berakhir" 
                    : "${sisa.inDays} Hari  :  ${sisa.inHours % 24} Jam  :  ${sisa.inMinutes % 60} Menit",
                  style: TextStyle(
                    fontSize: 15, 
                    fontWeight: FontWeight.bold, 
                    color: isExpired ? Colors.red : Colors.black87
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadBox() {
    return GestureDetector(
      onTap: _isUploading ? null : _pickImage,
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: _imageBytes == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Icon(Icons.cloud_upload_outlined, size: 50, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text("Lampirkan Bukti Transfer", style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
                Text("(JPG/PNG, Max 2MB)", style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(_imageBytes!, fit: BoxFit.contain, gaplessPlayback: true),
                if (!_isUploading)
                  Positioned(
                    right: 12, top: 12,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                        onPressed: _pickImage,
                      ),
                    ),
                  )
              ],
            ),
      ),
    );
  }

  Widget _buildHorizontalLoading() {
    return Column(
      children: [
        Text("Sedang memproses pembayaran...", style: TextStyle(color: primaryNavy, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 15),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(primaryNavy),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isExpired) {
  return SizedBox(
    width: double.infinity,
    height: 60,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        // Jika telat, beri warna sedikit berbeda atau tetap navy
        backgroundColor: isExpired ? Colors.orange[800] : primaryNavy, 
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
      // Sekarang onPressed selalu aktif selama tidak sedang uploading
      onPressed: _isUploading ? null : _kirimPembayaran, 
      child: Text(
        isExpired ? "BAYAR (TERLAMBAT)" : "KIRIM KONFIRMASI",
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1),
      ),
    ),
  );
}

  Widget _buildInputField({required TextEditingController controller, required String label, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
          prefixIcon: Icon(icon, color: primaryNavy, size: 22),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey.withOpacity(0.1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: primaryNavy.withOpacity(0.5))),
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        ),
      ),
    );
  }
}