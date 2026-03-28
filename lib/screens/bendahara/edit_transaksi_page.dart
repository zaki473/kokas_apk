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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Inisialisasi data lama ke dalam form
    _ketController = TextEditingController(text: widget.currentData['keterangan']);
    _jumlahController = TextEditingController(text: widget.currentData['jumlah'].toString());
    _type = widget.currentData['type'];
  }

  void _updateTransaksi() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance.collection('transactions').doc(widget.docId).update({
          'keterangan': _ketController.text,
          'jumlah': int.parse(_jumlahController.text.replaceAll('.', '').replaceAll('Rp ', '')),
          'type': _type,
        });

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Transaksi berhasil diperbarui"),
            backgroundColor: Colors.indigo,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal update: $e"), backgroundColor: Colors.red),
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
        title: const Text("Edit Transaksi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Header
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
                  // --- PILIHAN JENIS (SEGMENTED CONTROL STYLE) ---
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
                  const Text("Koreksi Data", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                  const SizedBox(height: 15),

                  // --- INPUT KETERANGAN ---
                  _buildInputField(
                    controller: _ketController,
                    label: "Keterangan",
                    hint: "Ubah keterangan...",
                    icon: Icons.edit_note_rounded,
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
                      if (int.tryParse(v) == null) return "Harus angka";
                      return null;
                    },
                  ),

                  const SizedBox(height: 40),

                  // --- TOMBOL SIMPAN PERUBAHAN ---
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
                      onPressed: _isLoading ? null : _updateTransaksi,
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline_rounded),
                              SizedBox(width: 10),
                              Text("SIMPAN PERUBAHAN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  // WIDGET SELECTOR (SAMA DENGAN HALAMAN TAMBAH)
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