import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TambahTransaksiPage extends StatefulWidget {
  const TambahTransaksiPage({super.key});

  @override
  State<TambahTransaksiPage> createState() => _TambahTransaksiPageState();
}

class _TambahTransaksiPageState extends State<TambahTransaksiPage> {
  final _formKey = GlobalKey<FormState>();
  final _ketController = TextEditingController();
  final _jumlahController = TextEditingController();
  String _type = 'masuk'; // Default transaksi masuk

  void _simpanTransaksi() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection('transactions').add({
        'keterangan': _ketController.text,
        'jumlah': int.parse(_jumlahController.text),
        'type': _type,
        'date': DateTime.now(),
      });
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tambah Transaksi"), backgroundColor: Colors.amber[700]),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Dropdown Pilih Jenis
              DropdownButtonFormField(
                value: _type,
                items: const [
                  DropdownMenuItem(value: 'masuk', child: Text("Uang Masuk (Kas)")),
                  DropdownMenuItem(value: 'keluar', child: Text("Uang Keluar (Belanja/Reimburse)")),
                ],
                onChanged: (val) => setState(() => _type = val as String),
                decoration: const InputDecoration(labelText: "Jenis Transaksi", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _ketController,
                decoration: const InputDecoration(labelText: "Keterangan (Contoh: Kas Januari)", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Isi keterangan" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _jumlahController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Jumlah (Rp)", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Isi jumlah" : null,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700]),
                  onPressed: _simpanTransaksi,
                  child: const Text("SIMPAN TRANSAKSI", style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}