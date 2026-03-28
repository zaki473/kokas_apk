import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // Tambahkan ini untuk Uint8List
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

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
  Uint8List? _imageBytes; // Tambahkan ini untuk menyimpan bytes gambar
  bool _isUploading = false;

  final Color primaryNavy = const Color(0xFF1A237E);

  // AMBIL GAMBAR & KOMPRES
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 20 
    );

    if (pickedFile != null) {
      File file = File(pickedFile.path);
      Uint8List bytes = await file.readAsBytes(); // Ambil bytes langsung
      setState(() {
        _imageBytes = bytes; // Simpan bytes untuk preview agar tidak berkedip
        _base64Image = base64Encode(bytes); // Simpan string untuk upload ke Firestore
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
        if (user == null) return;

        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users') 
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          throw "Dokumen user tidak ditemukan di koleksi 'users'.";
        }

        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String? groupIdValue = userData['groupId']; 

        if (groupIdValue == null || groupIdValue.isEmpty) {
          throw "Field 'groupId' kosong di database.";
        }

        await FirebaseFirestore.instance.collection('reimbursements').add({
          'uid': user.uid,
          'groupId': groupIdValue,
          'nama_pengaju': userData['name'] ?? user.email,
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
            content: Text("Pengajuan berhasil dikirim!"),
            backgroundColor: Colors.indigo,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Kesalahan: $e"), backgroundColor: Colors.red),
        );
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
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: primaryNavy, size: 20),
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
                  Text("Detail Pengajuan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy)),
                  const SizedBox(height: 15),

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

                  _buildInputField(
                    controller: _keperluanController,
                    label: "Keperluan / Alasan",
                    hint: "Contoh: Beli alat tulis kantor",
                    icon: Icons.description_rounded,
                    maxLines: 3,
                    validator: (v) => v!.isEmpty ? "Isi alasan pengajuan" : null,
                  ),

                  const SizedBox(height: 25),
                  Text("Foto Nota / Kwitansi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy)),
                  const SizedBox(height: 15),

                  _buildUploadBox(),
                  
                  const SizedBox(height: 40),

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
        child: _imageBytes == null 
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
                // Menggunakan _imageBytes agar tidak perlu decode ulang saat UI refresh
                Image.memory(
                  _imageBytes!, 
                  fit: BoxFit.cover,
                  gaplessPlayback: true, // Mencegah kedip saat transisi gambar
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

  Widget _buildHorizontalLoading() {
    return Column(
      children: [
        Text("Sedang memproses pengajuan...", style: TextStyle(color: primaryNavy, fontSize: 12, fontWeight: FontWeight.bold)),
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

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 5,
          shadowColor: primaryNavy.withOpacity(0.4),
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