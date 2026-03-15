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
  final _jumlahController = TextEditingController(text: "10000"); // Contoh nominal default
  final _bulanController = TextEditingController();
  String? _base64Image;
  bool _isUploading = false;
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // FUNGSI AMBIL GAMBAR & CONVERT KE BASE64
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 25 // Kompres agar tidak lebih dari 1MB (limit Firestore)
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
    if (_base64Image == null || _bulanController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lengkapi data dan foto bukti!")));
      return;
    }

    setState(() => _isUploading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      
      await FirebaseFirestore.instance.collection('pembayaran').add({
        'uid': user!.uid,
        'nama_pengirim': user.email,
        'jumlah': int.parse(_jumlahController.text),
        'bulan': _bulanController.text,
        'url_bukti': _base64Image, // Menyimpan teks base64
        'status': 'pending',
        'tanggal_kirim': DateTime.now(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bukti terkirim! Menunggu verifikasi bendahara.")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bayar Kas"), backgroundColor: Colors.orange[700]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // STREAM DEADLINE
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('settings').doc('kas_deadline').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                DateTime deadline = (snapshot.data!['tanggal'] as Timestamp).toDate();
                Duration sisa = deadline.difference(_now);
                bool isExpired = _now.isAfter(deadline);

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isExpired ? Colors.red[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(isExpired ? "WAKTU HABIS" : "SISA WAKTU PEMBAYARAN", 
                        style: TextStyle(fontWeight: FontWeight.bold, color: isExpired ? Colors.red : Colors.green)),
                      Text(isExpired ? "Segera hubungi bendahara" : 
                        "${sisa.inDays} Hari ${sisa.inHours % 24}:${sisa.inMinutes % 60}:${sisa.inSeconds % 60}",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 25),
            TextField(
              controller: _bulanController,
              decoration: const InputDecoration(labelText: "Untuk Pembayaran Bulan (Contoh: Januari)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _jumlahController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Jumlah Bayar (Rp)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            
            // TOMBOL UPLOAD
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[100],
                ),
                child: _base64Image == null 
                  ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt), Text("Klik untuk Upload Bukti Transfer")])
                  : Image.memory(base64Decode(_base64Image!), fit: BoxFit.cover),
              ),
            ),
            
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
                onPressed: _isUploading ? null : _kirimPembayaran,
                child: _isUploading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("KIRIM BUKTI PEMBAYARAN", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}