import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Tambahan untuk input formatter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/error_service.dart'; // Pastikan path ini benar

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
  String? _myGroupId; // Diubah agar dinamis dari Firestore

  @override
  void initState() {
    super.initState();
    _getGroupId();
  }

  @override
  void dispose() {
    _ketController.dispose();
    _jumlahController.dispose();
    super.dispose();
  }

  // Ambil groupId yang benar (sama dengan halaman verifikasi)
  Future<void> _getGroupId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _myGroupId = doc.data()?['groupId'];
        });
      }
    }
  }

  void _simpanTransaksi() async {
    if (_myGroupId == null) {
      _showSnackBar("Gagal: Group ID tidak ditemukan", Colors.red);
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final firestore = FirebaseFirestore.instance;
        final String keterangan = _ketController.text.trim();
        // Parsing angka dengan aman dari format ribuan
        final int jumlah = int.parse(_jumlahController.text.replaceAll('.', ''));
        final DateTime sekarang = DateTime.now();

        final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
        String jumlahFormatted = currency.format(jumlah);

        WriteBatch batch = firestore.batch();

        // 1. Simpan ke koleksi transaksi
        DocumentReference transRef = firestore.collection('transactions').doc();
        batch.set(transRef, {
          'keterangan': keterangan,
          'jumlah': jumlah,
          'type': _type,
          'groupId': _myGroupId,
          'date': sekarang,
        });

        // 2. Jika pengeluaran, buat pengumuman otomatis
        if (_type == 'keluar') {
          DocumentReference annRef = firestore.collection('announcements').doc();
          batch.set(annRef, {
            'pesan': '📢 PENGELUARAN: $keterangan senilai $jumlahFormatted',
            'tanggal': sekarang,
            'groupId': _myGroupId,
          });
        }

        await batch.commit();

        if (!mounted) return;
        Navigator.pop(context);
        ErrorService.showSuccess(context, "Transaksi berhasil disimpan!"); 
      } catch (e) {
        ErrorService.show(context, e);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    // UI TETAP SAMA SEPERTI REQUEST
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        title: const Text("Input Transaksi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Container(
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
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
                  _buildInputField(
                    controller: _ketController,
                    label: "Keterangan",
                    hint: "Contoh: Bayar Listrik / Iuran Kas",
                    icon: Icons.description_outlined,
                    validator: (v) => v!.isEmpty ? "Isi keterangan" : null,
                  ),
                  const SizedBox(height: 20),
                  _buildInputField(
                    controller: _jumlahController,
                    label: "Jumlah Nominal",
                    hint: "0",
                    icon: Icons.payments_outlined,
                    isNumber: true,
                    prefix: "Rp ",
                    // Formatter ribuan otomatis
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(),
                    ],
                    validator: (v) {
                      if (v!.isEmpty) return "Isi jumlah";
                      return null;
                    },
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: _isLoading || _myGroupId == null ? null : _simpanTransaksi,
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

  Widget _buildTypeSelector(String typeValue, String label, IconData icon, Color color) {
    bool isSelected = _type == typeValue;
    return GestureDetector(
      onTap: () => setState(() => _type = typeValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(color: isSelected ? color : Colors.transparent, borderRadius: BorderRadius.circular(15)),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    String? prefix,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: validator,
        inputFormatters: inputFormatters,
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

// FORMATTER UNTUK RIBUAN (1.000.000)
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    int value = int.parse(newValue.text.replaceAll('.', ''));
    final formatter = NumberFormat.decimalPattern('id');
    final newString = formatter.format(value);
    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}