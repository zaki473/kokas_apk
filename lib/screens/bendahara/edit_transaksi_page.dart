import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditTransaksiPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> currentData;

  const EditTransaksiPage({super.key, required this.docId, required this.currentData});

  @override
  State<EditTransaksiPage> createState() => _EditTransaksiPageState();
}

class _EditTransaksiPageState extends State<EditTransaksiPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ketController;
  late TextEditingController _jumlahController;
  late String _type;

  @override
  void initState() {
    super.initState();
    // Isi controller dengan data lama
    _ketController = TextEditingController(text: widget.currentData['keterangan']);
    _jumlahController = TextEditingController(text: widget.currentData['jumlah'].toString());
    _type = widget.currentData['type'];
  }

  void _updateTransaksi() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection('transactions').doc(widget.docId).update({
        'keterangan': _ketController.text,
        'jumlah': int.parse(_jumlahController.text),
        'type': _type,
        // tanggal tidak diupdate agar tetap sesuai tanggal awal input
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transaksi berhasil diperbarui")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Transaksi"), backgroundColor: Colors.amber[700]),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField(
                initialValue: _type,
                items: const [
                  DropdownMenuItem(value: 'masuk', child: Text("Uang Masuk (Kas)")),
                  DropdownMenuItem(value: 'keluar', child: Text("Uang Keluar")),
                ],
                onChanged: (val) => setState(() => _type = val as String),
                decoration: const InputDecoration(labelText: "Jenis Transaksi", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _ketController,
                decoration: const InputDecoration(labelText: "Keterangan", border: OutlineInputBorder()),
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
                  onPressed: _updateTransaksi,
                  child: const Text("SIMPAN PERUBAHAN", style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}