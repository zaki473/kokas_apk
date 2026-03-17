import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  bool _isLoading = false;

  void _simpanTransaksi() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final firestore = FirebaseFirestore.instance;
        final String keterangan = _ketController.text;
        final int jumlah = int.parse(_jumlahController.text);
        final DateTime sekarang = DateTime.now();

        // Format Rupiah untuk isi pesan pengumuman
        final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
        String jumlahFormatted = currency.format(jumlah);

        // MENGGUNAKAN BATCH WRITE (Agar transaksi & pengumuman masuk berbarengan)
        WriteBatch batch = firestore.batch();

        // 1. Simpan ke koleksi transactions
        DocumentReference transRef = firestore.collection('transactions').doc();
        batch.set(transRef, {
          'keterangan': keterangan,
          'jumlah': jumlah,
          'type': _type,
          'date': sekarang,
        });

        // 2. OTOMATIS buat pengumuman jika jenisnya 'keluar'
        if (_type == 'keluar') {
          DocumentReference annRef = firestore.collection('announcements').doc();
          batch.set(annRef, {
            'pesan': '📢 PENGELUARAN: $keterangan senilai $jumlahFormatted',
            'tanggal': sekarang,
          });
        }

        // Eksekusi Batch
        await batch.commit();

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Transaksi berhasil disimpan!"), backgroundColor: Colors.green),
        );
      } catch (e) {
        // Jika muncul Permission Denied lagi, cek apakah role di Firestore sudah 'bendahara'
        print("Error detail: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal Simpan: $e"), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tambah Transaksi"), 
        backgroundColor: Colors.amber[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Dropdown Pilih Jenis
              DropdownButtonFormField(
                initialValue: _type,
                items: const [
                  DropdownMenuItem(value: 'masuk', child: Text("Uang Masuk (Kas)")),
                  DropdownMenuItem(value: 'keluar', child: Text("Uang Keluar (Belanja/Reimburse)")),
                ],
                onChanged: (val) => setState(() => _type = val as String),
                decoration: const InputDecoration(
                  labelText: "Jenis Transaksi", 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.compare_arrows),
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _ketController,
                decoration: const InputDecoration(
                  labelText: "Keterangan", 
                  border: OutlineInputBorder(),
                  hintText: "Contoh: Beli alat kebersihan",
                ),
                validator: (v) => v!.isEmpty ? "Isi keterangan" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _jumlahController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Jumlah (Rp)", 
                  border: OutlineInputBorder(),
                  prefixText: "Rp ",
                ),
                validator: (v) {
                  if (v!.isEmpty) return "Isi jumlah";
                  if (int.tryParse(v) == null) return "Harus berupa angka";
                  return null;
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isLoading ? null : _simpanTransaksi,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "SIMPAN TRANSAKSI", 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}