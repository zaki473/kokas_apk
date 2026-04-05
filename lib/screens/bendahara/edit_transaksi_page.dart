import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '/services/error_service.dart';

class EditTransaksiPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> currentData;

  const EditTransaksiPage({
    super.key,
    required this.docId,
    required this.currentData,
  });

  @override
  State<EditTransaksiPage> createState() => _EditTransaksiPageState();
}

class _EditTransaksiPageState extends State<EditTransaksiPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ketController;
  late TextEditingController _jumlahController;
  late String _type;
  bool _isLoading = false;

  final _formatter = NumberFormat.decimalPattern('id');
  final Color primaryNavy = const Color(0xFF1A237E);

  @override
  void initState() {
    super.initState();
    _ketController = TextEditingController(text: widget.currentData['keterangan'] ?? "");

    // Parsing aman untuk nominal awal
    num initialAmount = widget.currentData['jumlah'] ?? 0;
    _jumlahController = TextEditingController(text: _formatter.format(initialAmount.toInt()));

    _type = widget.currentData['type'] ?? 'masuk';
  }

  @override
  void dispose() {
    _ketController.dispose();
    _jumlahController.dispose();
    super.dispose();
  }

  void _updateTransaksi() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final cleanAmount = _jumlahController.text.replaceAll('.', '').replaceAll('Rp ', '');
        final finalAmount = int.tryParse(cleanAmount) ?? 0;

        await FirebaseFirestore.instance
            .collection('transactions')
            .doc(widget.docId)
            .update({
          'keterangan': _ketController.text.trim(),
          'jumlah': finalAmount,
          'type': _type,
          'updatedAt': FieldValue.serverTimestamp(), // Tambahkan audit log simpel
        });

        if (!mounted) return;
        Navigator.pop(context);
        ErrorService.showSuccess(context, "Transaksi berhasil diperbarui");
      } catch (e) {
        ErrorService.show(context, e);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryNavy,
        title: const Text("Edit Transaksi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
            padding: const EdgeInsets.fromLTRB(25, 10, 25, 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type Selector Card
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _buildTypeSelector("masuk", "Pemasukan", Icons.add_circle_outline, Colors.green)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildTypeSelector("keluar", "Pengeluaran", Icons.remove_circle_outline, Colors.red)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  Text("Informasi Transaksi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy)),
                  const SizedBox(height: 15),

                  _buildInputField(
                    controller: _ketController,
                    label: "Keterangan",
                    hint: "Contoh: Iuran Kas Minggu 1",
                    icon: Icons.edit_note_rounded,
                    validator: (v) => v!.isEmpty ? "Keterangan tidak boleh kosong" : null,
                  ),

                  const SizedBox(height: 20),

                  _buildInputField(
                    controller: _jumlahController,
                    label: "Nominal",
                    hint: "0",
                    icon: Icons.payments_outlined,
                    isNumber: true,
                    prefix: "Rp ",
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(),
                    ],
                    validator: (v) => v!.isEmpty ? "Masukkan jumlah nominal" : null,
                  ),

                  const SizedBox(height: 40),

                  _isLoading ? _buildLoadingIndicator() : _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(String value, String label, IconData icon, Color activeColor) {
    bool isSelected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.grey[50]?.withValues(alpha: 0.5) ?? Colors.grey[50]!,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? activeColor : Colors.grey[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey[400], size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 2,
        ),
        onPressed: _updateTransaksi,
        child: const Text("SIMPAN PERUBAHAN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.1)),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        children: [
          CircularProgressIndicator(color: primaryNavy),
          const SizedBox(height: 15),
          const Text("Menyimpan perubahan...", style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
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
        prefixIcon: Icon(icon, color: primaryNavy),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: primaryNavy, width: 2)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
    );
  }
}

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
