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
  String _type = 'masuk'; 
  bool _isLoading = false;

  void _simpanTransaksi() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final firestore = FirebaseFirestore.instance;
        final String keterangan = _ketController.text;
        final int jumlah = int.parse(_jumlahController.text.replaceAll('.', '')); // Hapus titik jika ada
        final DateTime sekarang = DateTime.now();

        final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
        String jumlahFormatted = currency.format(jumlah);

        WriteBatch batch = firestore.batch();

        DocumentReference transRef = firestore.collection('transactions').doc();
        batch.set(transRef, {
          'keterangan': keterangan,
          'jumlah': jumlah,
          'type': _type,
          'date': sekarang,
        });

        if (_type == 'keluar') {
          DocumentReference annRef = firestore.collection('announcements').doc();
          batch.set(annRef, {
            'pesan': '📢 PENGELUARAN: $keterangan senilai $jumlahFormatted',
            'tanggal': sekarang,
          });
        }

        await batch.commit();

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Transaksi berhasil disimpan!"),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
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
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E), // Navy Dashboard
        title: const Text("Input Transaksi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Biru di atas (setengah)
          Container(
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
          
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CARD PILIHAN JENIS (SEGMENTED LOOK) ---
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildTypeSelector("masuk", "Uang Masuk", Icons.arrow_downward, Colors.green)),
                        Expanded(child: _buildTypeSelector("keluar", "Uang Keluar", Icons.arrow_upward, Colors.red)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 25),
                  const Text("Detail Transaksi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                  const SizedBox(height: 15),

                  // --- INPUT KETERANGAN ---
                  _buildInputField(
                    controller: _ketController,
                    label: "Keterangan",
                    hint: "Contoh: Bayar Listrik / Iuran Kas",
                    icon: Icons.description_outlined,
                    validator: (v) => v!.isEmpty ? "Isi keterangan" : null,
                  ),

                  const SizedBox(height: 20),

                  // --- INPUT JUMLAH ---
                  _buildInputField(
                    controller: _jumlahController,
                    label: "Jumlah Nominal",
                    hint: "0",
                    icon: Icons.payments_outlined,
                    isNumber: true,
                    prefix: "Rp ",
                    validator: (v) {
                      if (v!.isEmpty) return "Isi jumlah";
                      if (int.tryParse(v.replaceAll('.', '')) == null) return "Harus angka";
                      return null;
                    },
                  ),

                  const SizedBox(height: 40),

                  // --- TOMBOL SIMPAN ---
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        elevation: 5,
                        shadowColor: const Color(0xFF1A237E).withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: _isLoading ? null : _simpanTransaksi,
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save_rounded),
                              SizedBox(width: 10),
                              Text("SIMPAN TRANSAKSI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                            ],
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET SELECTOR MASUK/KELUAR
  Widget _buildTypeSelector(String typeValue, String label, IconData icon, Color color) {
    bool isSelected = _type == typeValue;
    return GestureDetector(
      onTap: () => setState(() => _type = typeValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // WIDGET TEXT FIELD CUSTOM
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    String? prefix,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: validator,
        style: const TextStyle(fontWeight: FontWeight.bold),
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