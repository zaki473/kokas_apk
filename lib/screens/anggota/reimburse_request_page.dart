import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:intl/intl.dart';

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
  bool _isUploading = false;

  // AMBIL GAMBAR & KOMPRES (Agar muat di Firestore & tidak lag)
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 20 // Kompresi tinggi untuk base64 agar performa tetap ringan
    );

    if (pickedFile != null) {
      File file = File(pickedFile.path);
      List<int> imageBytes = await file.readAsBytes();
      setState(() {
        _base64Image = base64Encode(imageBytes);
      });
    }
  }

  void _kirimRequest() async {
    if (_formKey.currentState!.validate()) {
      if (_base64Image == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mohon upload bukti nota/struk!"), backgroundColor: Colors.redAccent),
        );
        return;
      }

      setState(() => _isUploading = true);
      try {
        User? user = FirebaseAuth.instance.currentUser;
        
        await FirebaseFirestore.instance.collection('reimbursements').add({
          'uid': user!.uid,
          'nama_pengaju': user.email,
          'jumlah': int.parse(_jumlahController.text.replaceAll('.', '')),
          'keperluan': _keperluanController.text.trim(),
          'url_bukti': _base64Image,
          'status': 'pending',
          'tanggal_kirim': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pengajuan reimburse terkirim! Menunggu verifikasi."),
            backgroundColor: Colors.indigo,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  void dispose() {
    _jumlahController.dispose();
    _keperluanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E), // Navy Theme
        title: const Text("Ajukan Reimburse", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Header Melengkung
          Container(
            height: 100,
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
                  const SizedBox(height: 10),
                  // Info Box Singkat
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF1A237E), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Pastikan foto nota terlihat jelas untuk mempercepat proses verifikasi.",
                            style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),
                  const Text("Detail Pengajuan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                  const SizedBox(height: 15),

                  // INPUT JUMLAH
                  _buildInputField(
                    controller: _jumlahController,
                    label: "Nominal Dana (Rp)",
                    hint: "0",
                    icon: Icons.payments_rounded,
                    isNumber: true,
                    prefix: "Rp ",
                    validator: (v) => v!.isEmpty ? "Isi jumlah dana" : null,
                  ),

                  const SizedBox(height: 15),

                  // INPUT KEPERLUAN
                  _buildInputField(
                    controller: _keperluanController,
                    label: "Keperluan / Alasan",
                    hint: "Contoh: Beli alat tulis kantor",
                    icon: Icons.description_rounded,
                    maxLines: 3,
                    validator: (v) => v!.isEmpty ? "Isi alasan pengajuan" : null,
                  ),

                  const SizedBox(height: 25),
                  const Text("Foto Nota / Kwitansi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                  const SizedBox(height: 15),

                  // UPLOAD BOX PREVIEW
                  _buildUploadBox(),
                  
                  const SizedBox(height: 40),

                  // TOMBOL KIRIM DENGAN LOADING HORIZONTAL
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

  Widget _buildUploadBox() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        clipBehavior: Clip.antiAlias,
        child: _base64Image == null 
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Icon(Icons.add_photo_alternate_rounded, size: 50, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text("Klik untuk Lampirkan Nota", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(base64Decode(_base64Image!), fit: BoxFit.cover),
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

  Widget _buildHorizontalLoading() {
    return Column(
      children: [
        const Text("Sedang memproses pengajuan...", style: TextStyle(color: Color(0xFF1A237E), fontSize: 12, fontWeight: FontWeight.bold)),
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
        onPressed: _kirimRequest,
        child: const Text("KIRIM PENGAJUAN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    int maxLines = 1,
    String? prefix,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefix,
          prefixIcon: Icon(icon, color: const Color(0xFF1A237E)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
      ),
    );
  }
}