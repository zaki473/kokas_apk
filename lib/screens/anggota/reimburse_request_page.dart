import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '/services/error_service.dart';

class ReimburseRequestPage extends StatefulWidget {
  const ReimburseRequestPage({super.key});

  @override
  State<ReimburseRequestPage> createState() => _ReimburseRequestPageState();
}

class _ReimburseRequestPageState extends State<ReimburseRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController();
  final _keperluanController = TextEditingController();
  
  String? _base64Image;
  Uint8List? _imageBytes;
  bool _isUploading = false;
  String? _groupId;

  final Color primaryNavy = const Color(0xFF1A237E);

  @override
  void initState() {
    super.initState();
    _preLoadUserData(); // Ambil GroupID lebih awal agar saat klik kirim lebih cepat
  }

  Future<void> _preLoadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() => _groupId = doc['groupId']);
      }
    }
  }

  Future<void> _pickImage() async {
    if (_isUploading) return;
    
    final picker = ImagePicker();
    // Gunakan max width/height untuk memastikan ukuran file kecil (di bawah limit Firestore 1MB)
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 25, 
      maxWidth: 1080, 
    );

    if (pickedFile != null) {
      Uint8List bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _base64Image = base64Encode(bytes);
      });
    }
  }

  void _kirimRequest() async {
    if (_formKey.currentState!.validate()) {
      if (_base64Image == null) {
        _showSnackBar("Mohon lampirkan foto nota/struk!", Colors.orangeAccent);
        return;
      }

      if (_groupId == null) {
        _showSnackBar("Gagal memuat data grup. Coba beberapa saat lagi.", Colors.red);
        _preLoadUserData();
        return;
      }

      // Tutup keyboard
      FocusScope.of(context).unfocus();

      setState(() => _isUploading = true);
      try {
        final user = FirebaseAuth.instance.currentUser!;
        
        // Cek ukuran Base64 (Warning jika mendekati 1MB)
        if (_base64Image!.length > 900000) {
          throw "Ukuran gambar terlalu besar. Silakan coba foto kembali dengan resolusi lebih rendah.";
        }

        await FirebaseFirestore.instance.collection('reimbursements').add({
          'uid': user.uid,
          'groupId': _groupId,
          'nama_pengaju': user.displayName ?? user.email,
          'jumlah': int.parse(_jumlahController.text.replaceAll('.', '').replaceAll('Rp ', '')),
          'keperluan': _keperluanController.text.trim(),
          'url_bukti': _base64Image,
          'status': 'pending',
          'tanggal_kirim': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        Navigator.pop(context);
        ErrorService.showSuccess(context, "Pengajuan berhasil dikirim");
      } catch (e) {
        ErrorService.show(context, e);
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _jumlahController.dispose();
    _keperluanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isUploading, // Mencegah user keluar saat sedang upload
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Ketuk luar untuk tutup keyboard
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F6F8),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: primaryNavy,
            title: const Text("Ajukan Reimburse", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 15),
                      _buildInfoTip(),
                      const SizedBox(height: 25),
                      Text("Detail Pengajuan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy)),
                      const SizedBox(height: 15),
                      _buildInputField(
                        controller: _jumlahController,
                        label: "Nominal Dana",
                        hint: "Contoh: 50.000",
                        icon: Icons.payments_rounded,
                        isNumber: true,
                        validator: (v) => v!.isEmpty ? "Isi jumlah dana" : null,
                      ),
                      const SizedBox(height: 15),
                      _buildInputField(
                        controller: _keperluanController,
                        label: "Keperluan / Alasan",
                        hint: "Tulis rincian barang yang dibeli...",
                        icon: Icons.description_rounded,
                        maxLines: 3,
                        validator: (v) => v!.isEmpty ? "Isi alasan pengajuan" : null,
                      ),
                      const SizedBox(height: 25),
                      Text("Foto Nota / Kwitansi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy)),
                      const SizedBox(height: 15),
                      _buildUploadBox(),
                      const SizedBox(height: 40),
                      _isUploading ? _buildHorizontalLoading() : _buildSubmitButton(),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTip() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: primaryNavy, size: 20),
          const SizedBox(width: 10),
          const Expanded(child: Text("Dana akan dicairkan oleh bendahara setelah disetujui.", style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildUploadBox() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200, width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: _imageBytes == null 
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Icon(Icons.add_a_photo_rounded, size: 40, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text("Klik untuk Upload Nota", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(_imageBytes!, fit: BoxFit.cover, gaplessPlayback: true),
                if (!_isUploading)
                  Positioned(
                    right: 12, top: 12,
                    child: CircleAvatar(backgroundColor: Colors.black54, radius: 18, child: const Icon(Icons.refresh, color: Colors.white, size: 20)),
                  )
              ],
            ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity, height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNavy, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: _kirimRequest,
        child: const Text("KIRIM PENGAJUAN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Widget _buildHorizontalLoading() {
    return Column(
      children: [
        const Text("Memproses pengajuan...", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        LinearProgressIndicator(backgroundColor: Colors.white, valueColor: AlwaysStoppedAnimation<Color>(primaryNavy)),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label, hintText: hint, prefixIcon: Icon(icon, color: primaryNavy),
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}