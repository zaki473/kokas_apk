import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  final _jumlahController = TextEditingController();
  final _keperluanController = TextEditingController();
  String? _base64Image;
  bool _isUploading = false;

  // FUNGSI AMBIL GAMBAR & CONVERT KE BASE64
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 20 // Sangat penting: Kompres kecil agar muat di Firestore (max 1MB)
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
    if (_base64Image == null || _jumlahController.text.isEmpty || _keperluanController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lengkapi data dan foto nota!"))
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      
      await FirebaseFirestore.instance.collection('reimbursements').add({
        'uid': user!.uid,
        'nama_pengaju': user.email,
        'jumlah': int.parse(_jumlahController.text),
        'keperluan': _keperluanController.text,
        'url_bukti': _base64Image, // Menyimpan teks base64
        'status': 'pending',
        'tanggal_kirim': DateTime.now(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pengajuan reimburse terkirim!"))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"))
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
      appBar: AppBar(
        title: const Text("Ajukan Reimburse"), 
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Formulir Pengajuan",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _jumlahController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Jumlah (Rp)", 
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.money),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _keperluanController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Keperluan / Alasan", 
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            
            const Text("Upload Bukti Nota:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // TOMBOL UPLOAD (Sama dengan UI BayarKas)
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[100],
                ),
                child: _base64Image == null 
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("Klik untuk Upload Bukti Nota", style: TextStyle(color: Colors.grey))
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(base64Decode(_base64Image!), fit: BoxFit.cover),
                    ),
              ),
            ),
            
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                onPressed: _isUploading ? null : _kirimRequest,
                child: _isUploading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("KIRIM PENGAJUAN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}