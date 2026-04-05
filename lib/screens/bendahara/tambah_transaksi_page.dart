import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/error_service.dart';

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
  String? _myGroupId;
  String _userName = "Sistem";

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

  Future<void> _getGroupId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted) {
          setState(() {
            _myGroupId = doc.data()?['groupId'];
            _userName = doc.data()?['name'] ?? "Bendahara";
          });
        }
      } catch (e) {
        if (mounted) ErrorService.show(context, e);
      }
    }
  }

  void _simpanTransaksi() async {
    if (_myGroupId == null) {
      ErrorService.show(context, "ID Grup tidak ditemukan. Silahkan login ulang.");
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final firestore = FirebaseFirestore.instance;
        final String keterangan = _ketController.text.trim();
        final int jumlah = int.parse(_jumlahController.text.replaceAll('.', ''));
        final DateTime sekarang = DateTime.now();

        final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
        String jumlahFormatted = currency.format(jumlah);

        WriteBatch batch = firestore.batch();

        // 1. Simpan Transaksi
        DocumentReference transRef = firestore.collection('transactions').doc();
        batch.set(transRef, {
          'keterangan': keterangan,
          'jumlah': jumlah,
          'type': _type,
          'groupId': _myGroupId,
          'date': sekarang,
        });

        // 2. Automasi Pengumuman jika pengeluaran
        if (_type == 'keluar') {
          DocumentReference annRef = firestore.collection('announcements').doc();
          batch.set(annRef, {
            'pesan': '📢 PENGELUARAN: $keterangan senilai $jumlahFormatted',
            'tanggal': sekarang,
            'groupId': _myGroupId,
            'author': _userName,
            'isAuto': true, 
          });
        }

        await batch.commit();

        if (!mounted) return;
        Navigator.pop(context);
        ErrorService.showSuccess(context, "Berhasil mencatat ${isMasuk ? 'pemasukan' : 'pengeluaran'}!"); 
      } catch (e) {
        if (mounted) ErrorService.show(context, e);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  bool get isMasuk => _type == 'masuk';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(25, 5, 25, 25),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selector Tipe
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildTypeSelector("masuk", "Uang Masuk", Icons.add_circle_outline, Colors.green)),
                        Expanded(child: _buildTypeSelector("keluar", "Uang Keluar", Icons.remove_circle_outline, Colors.red)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Label Dinamis
                  Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: isMasuk ? Colors.green : Colors.red),
                      const SizedBox(width: 8),
                      Text("Detail ${isMasuk ? 'Pemasukan' : 'Pengeluaran'}", 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                    ],
                  ),
                  const SizedBox(height: 15),

                  _buildInputField(
                    controller: _ketController,
                    label: "Keterangan",
                    hint: isMasuk ? "Contoh: Iuran Kas Bulanan" : "Contoh: Beli Atk / Konsumsi",
                    icon: Icons.notes_rounded,
                    validator: (v) => v!.isEmpty ? "Keterangan wajib diisi" : null,
                  ),
                  const SizedBox(height: 20),
                  
                  _buildInputField(
                    controller: _jumlahController,
                    label: "Nominal",
                    hint: "0",
                    icon: Icons.account_balance_wallet_outlined,
                    isNumber: true,
                    prefix: "Rp ",
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(),
                    ],
                    validator: (v) {
                      if (v!.isEmpty) return "Nominal tidak boleh kosong";
                      if (v == "0") return "Nominal tidak boleh nol";
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isMasuk ? const Color(0xFF1A237E) : Colors.red[900],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 4,
                      ),
                      onPressed: _isLoading || _myGroupId == null ? null : _simpanTransaksi,
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("SIMPAN DATA", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(15)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
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
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: validator,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        prefixIcon: Icon(icon, size: 22),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey[200]!)),
      ),
    );
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    
    // Hapus semua titik untuk mendapatkan angka murni
    String plainNumber = newValue.text.replaceAll('.', '');
    if (plainNumber.isEmpty) return newValue;

    final formatter = NumberFormat.decimalPattern('id');
    String newString = formatter.format(int.parse(plainNumber));

    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}