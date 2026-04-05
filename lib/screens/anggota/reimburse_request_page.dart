import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Tambahkan ini
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // Tambahkan ini
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
    _preLoadUserData();
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
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 20, // Kualitas dikurangi sedikit lagi agar lebih aman di Firestore
      maxWidth: 800,    // Max 800px cukup untuk baca nota
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

      FocusScope.of(context).unfocus();
      setState(() => _isUploading = true);

      try {
        final user = FirebaseAuth.instance.currentUser!;
        
        if (_base64Image!.length > 950000) {
          throw "Ukuran gambar terlalu besar. Silakan kompres atau pilih foto lain.";
        }

        // Parsing angka dengan aman
        String cleanNominal = _jumlahController.text.replaceAll('.', '').replaceAll('Rp ', '');
        int nominal = int.tryParse(cleanNominal) ?? 0;

        await FirebaseFirestore.instance.collection('reimbursements').add({
          'uid': user.uid,
          'groupId': _groupId,
          'nama_pengaju': user.displayName ?? user.email,
          'jumlah': nominal,
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
    _jumlahController.dispose();
    _keperluanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isUploading,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
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
                height: 60,
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
                      const SizedBox(height: 10),
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
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CurrencyInputFormatter(),
                        ],
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

  // --- WIDGET HELPERS ---

  Widget _buildInfoTip() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: primaryNavy, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Dana akan dicairkan oleh bendahara setelah verifikasi nota disetujui.", 
              style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black87)
            )
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
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: _imageBytes == null 
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text("Ambil Foto Nota", style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
                Text("Max 1MB (JPG/PNG)", style: TextStyle(color: Colors.grey[400], fontSize: 11)),
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
                      radius: 20, 
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 20)
                    ),
                  )
              ],
            ),
      ),
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
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: _kirimRequest,
        child: const Text("KIRIM PENGAJUAN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)),
      ),
    );
  }

  Widget _buildHorizontalLoading() {
    return Column(
      children: [
        Text("Sedang mengirim pengajuan...", style: TextStyle(color: primaryNavy, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 15),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            minHeight: 8,
            backgroundColor: Colors.grey[200], 
            valueColor: AlwaysStoppedAnimation<Color>(primaryNavy)
          ),
        ),
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
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        validator: validator,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label, 
          hintText: hint, 
          prefixIcon: Icon(icon, color: primaryNavy, size: 22),
          filled: true, 
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey.withOpacity(0.1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: primaryNavy)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}

// Helper untuk format mata uang saat mengetik
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) return newValue;
    double value = double.parse(newValue.text);
    final formatter = NumberFormat.decimalPattern('id');
    String newText = formatter.format(value);
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}