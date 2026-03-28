import 'dart:async';
import 'dart:convert';
import 'dart:typed_data'; // Tambahkan ini untuk Uint8List
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../image_helper.dart'; 

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
  Uint8List? _imageBytes; // Simpan bytes gambar di sini
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

    // Jalankan timer untuk update sisa waktu
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _loadUserGroupId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      setState(() => _myGroupId = userDoc['groupId']);
    }
  }

  Future<void> _pickImage() async {
    String? img = await ImageHelper.pickAndCompress();
    if (img != null) {
      setState(() {
        _base64Image = img;
        _imageBytes = base64Decode(img); // Decode di sini, HANYA SEKALI
      });
    }
  }

  void _kirimPembayaran() async {
    if (DateTime.now().isAfter(widget.deadline)) {
      _showSnackBar("Sudah melewati deadline!", Colors.redAccent);
      return;
    }

    if (_base64Image == null) {
      _showSnackBar("Mohon lampirkan bukti transfer!", Colors.orangeAccent);
      return;
    }

    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      String docId = "${user.uid}_${widget.bulan}";

      await FirebaseFirestore.instance.collection('pembayaran').doc(docId).set({
        'uid_pengirim': user.uid,
        'nama_pengirim': user.email,
        'jumlah': widget.nominal,
        'bulan': widget.bulan,
        'url_bukti': _base64Image,
        'status': 'pending',
        'groupId': _myGroupId,
        'tanggal_kirim': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar("Pembayaran berhasil dikirim, menunggu verifikasi!", primaryNavy);
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
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

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryNavy,
        title: const Text("Konfirmasi Pembayaran", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: primaryNavy,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  
                  // BOX COUNTDOWN
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined, color: isExpired ? Colors.red : primaryNavy, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isExpired ? "WAKTU HABIS" : "SISA WAKTU PEMBAYARAN",
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                              ),
                              Text(
                                isExpired 
                                  ? "Batas waktu pelunasan telah berakhir" 
                                  : "${sisa.inDays} Hari  :  ${sisa.inHours % 24} Jam  :  ${sisa.inMinutes % 60} Menit",
                                style: TextStyle(
                                  fontSize: 14, 
                                  fontWeight: FontWeight.bold, 
                                  color: isExpired ? Colors.red : Colors.black87
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),
                  Text("Detail Tagihan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy)),
                  const SizedBox(height: 15),

                  _buildInputField(controller: _bulanController, label: "Bulan Iuran", icon: Icons.calendar_month_rounded),
                  const SizedBox(height: 15),
                  _buildInputField(controller: _jumlahController, label: "Total Tagihan", icon: Icons.account_balance_wallet_rounded),

                  const SizedBox(height: 25),
                  Text("Bukti Transfer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy)),
                  const SizedBox(height: 15),

                  _buildUploadBox(), // Widget gambar dipanggil di sini

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
    );
  }

  Widget _buildUploadBox() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        clipBehavior: Clip.antiAlias,
        child: _imageBytes == null // Gunakan variabel bytes, bukan base64 string
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Icon(Icons.add_a_photo_rounded, size: 50, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text("Klik untuk Unggah Bukti Bayar", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                // Menggunakan Image.memory dengan bytes yang sudah didecode sebelumnya
                Image.memory(
                  _imageBytes!, 
                  fit: BoxFit.cover,
                  gaplessPlayback: true, // Tambahkan ini agar transisi gambar mulus
                ),
                Positioned(
                  right: 12, top: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                      onPressed: _pickImage,
                    ),
                  ),
                )
              ],
            ),
      ),
    );
  }

  // Widget lainnya tetap sama...
  Widget _buildHorizontalLoading() {
    return Column(
      children: [
        Text("Sedang mengirim bukti pembayaran...", style: TextStyle(color: primaryNavy, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            minHeight: 6,
            backgroundColor: Colors.white,
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
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[400],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 5,
        ),
        onPressed: isExpired ? null : _kirimPembayaran,
        child: const Text("KIRIM KONFIRMASI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)),
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String label, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryNavy),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
      ),
    );
  }
}