import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:intl/intl.dart';

class BayarKasPage extends StatefulWidget {
  const BayarKasPage({super.key});

  @override
  State<BayarKasPage> createState() => _BayarKasPageState();
}

class _BayarKasPageState extends State<BayarKasPage> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController(text: "10000");
  final _bulanController = TextEditingController();
  String? _base64Image;
  bool _isUploading = false;
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Timer untuk countdown real-time
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _jumlahController.dispose();
    _bulanController.dispose();
    super.dispose();
  }

  // AMBIL GAMBAR & KOMPRES (Agar tidak lemot & tidak melebihi limit Firestore)
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 20 // Kompresi tinggi untuk performa base64
    );

    if (pickedFile != null) {
      File file = File(pickedFile.path);
      List<int> imageBytes = await file.readAsBytes();
      setState(() {
        _base64Image = base64Encode(imageBytes);
      });
    }
  }

  void _kirimPembayaran() async {
    if (_formKey.currentState!.validate()) {
      if (_base64Image == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mohon upload bukti transfer!"), backgroundColor: Colors.redAccent),
        );
        return;
      }

      setState(() => _isUploading = true);
      try {
        User? user = FirebaseAuth.instance.currentUser;
        
        await FirebaseFirestore.instance.collection('pembayaran').add({
          'uid_pengirim': user!.uid,
          'nama_pengirim': user.email,
          'jumlah': int.parse(_jumlahController.text.replaceAll('.', '')),
          'bulan': _bulanController.text,
          'url_bukti': _base64Image,
          'status': 'pending',
          'tanggal_kirim': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pembayaran terkirim! Menunggu verifikasi bendahara."),
            backgroundColor: Colors.indigo,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E), // Navy Theme
        title: const Text("Konfirmasi Pembayaran", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Navy Header Background
          Container(
            height: 120,
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
          ),
          
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SEKSI COUNTDOWN DEADLINE ---
                  _buildDeadlineCountdown(),

                  const SizedBox(height: 25),
                  const Text("Detail Pembayaran", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                  const SizedBox(height: 15),

                  // --- INPUT BULAN ---
                  _buildInputField(
                    controller: _bulanController,
                    label: "Untuk Pembayaran Bulan",
                    hint: "Contoh: Januari 2024",
                    icon: Icons.calendar_month_rounded,
                  ),

                  const SizedBox(height: 15),

                  // --- INPUT NOMINAL ---
                  _buildInputField(
                    controller: _jumlahController,
                    label: "Nominal Bayar",
                    hint: "10000",
                    icon: Icons.payments_rounded,
                    isNumber: true,
                    prefix: "Rp ",
                  ),

                  const SizedBox(height: 25),
                  const Text("Bukti Transfer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                  const SizedBox(height: 15),

                  // --- UPLOAD BOX ---
                  _buildUploadBox(),
                  
                  const SizedBox(height: 40),

                  // --- TOMBOL KIRIM & LOADING GARIS (NAVY) ---
                  _isUploading 
                    ? _buildHorizontalLoading()
                    : _buildSubmitButton(),
                  
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineCountdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('kas_deadline').orderBy('tanggal_deadline', descending: true).limit(1).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
        
        var data = snapshot.data!.docs.first;
        DateTime deadline = (data['tanggal_deadline'] as Timestamp).toDate();
        Duration sisa = deadline.difference(_now);
        bool isExpired = _now.isAfter(deadline);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined, color: isExpired ? Colors.red : Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text(isExpired ? "WAKTU PEMBAYARAN HABIS" : "SISA WAKTU PEMBAYARAN", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isExpired ? Colors.red : Colors.green)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isExpired ? "Segera hubungi bendahara" : 
                "${sisa.inDays} Hari ${sisa.inHours % 24}j ${sisa.inMinutes % 60}m ${sisa.inSeconds % 60}s",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A237E)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUploadBox() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: _base64Image == null 
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Icon(Icons.add_a_photo_rounded, size: 40, color: Colors.grey[400]),
                const SizedBox(height: 10),
                Text("Klik untuk Upload Bukti Transfer", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(base64Decode(_base64Image!), fit: BoxFit.cover),
                Positioned(
                  right: 10, top: 10,
                  child: CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _pickImage)),
                )
              ],
            ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    String? prefix,
  }) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: (v) => v!.isEmpty ? "Harus diisi" : null,
        decoration: InputDecoration(
          labelText: label, hintText: hint, prefixText: prefix,
          prefixIcon: Icon(icon, color: const Color(0xFF1A237E)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          filled: true, fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildHorizontalLoading() {
    return Column(
      children: [
        const Text("Mengirim bukti...", style: TextStyle(color: Color(0xFF1A237E), fontSize: 12, fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
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
        child: const Text("KIRIM KONFIRMASI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)),
      ),
    );
  }

  // Widget pembantu (Input Field Reuse)
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    String? prefix,
  }) {
    return _buildTextField(controller: controller, label: label, hint: hint, icon: icon, isNumber: isNumber, prefix: prefix);
  }
}