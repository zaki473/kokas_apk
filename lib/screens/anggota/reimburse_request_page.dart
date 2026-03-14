import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReimburseRequestPage extends StatefulWidget {
  const ReimburseRequestPage({super.key});

  @override
  State<ReimburseRequestPage> createState() => _ReimburseRequestPageState();
}

class _ReimburseRequestPageState extends State<ReimburseRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _jumlahController = TextEditingController();
  final _keperluanController = TextEditingController();
  bool _isLoading = false;

  void _kirimRequest() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      // Ambil data user yang sedang login
      User? user = FirebaseAuth.instance.currentUser;
      
      await FirebaseFirestore.instance.collection('reimbursements').add({
        'uid': user!.uid,
        'nama_anggota': user.email, // Idealnya ambil 'nama' dari Firestore users, tapi email cukup untuk identitas awal
        'jumlah': int.parse(_jumlahController.text),
        'keperluan': _keperluanController.text,
        'status': 'pending', // Default status
        'tanggal': DateTime.now(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permintaan Reimburse Terkirim!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ajukan Reimburse"), backgroundColor: Colors.blue[700]),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _jumlahController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Jumlah (Rp)", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Isi jumlah uang" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _keperluanController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Keperluan / Alasan", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Isi alasan reimburse" : null,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
                  onPressed: _isLoading ? null : _kirimRequest,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("KIRIM PENGAJUAN", style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}