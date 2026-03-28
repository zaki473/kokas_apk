import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class KasSettingPage extends StatefulWidget {
  const KasSettingPage({super.key});

  @override
  State<KasSettingPage> createState() => _KasSettingPageState();
}

class _KasSettingPageState extends State<KasSettingPage> {
  final _formKey = GlobalKey<FormState>();
  final String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  String? myGroupId;
  bool isLoading = true;
  bool isSaving = false;

  final TextEditingController _bulanController = TextEditingController();
  final TextEditingController _nominalController = TextEditingController(text: "10,000");

  DateTime? selectedDateTime;

  // Warna Tema Navy
  final Color primaryNavy = const Color(0xFF1A237E);
  final Color backgroundColor = const Color(0xFFF4F6F8);

  @override
  void initState() {
    super.initState();
    _loadGroupId();
  }

  Future<void> _loadGroupId() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
      if (userDoc.exists) {
        setState(() {
          myGroupId = userDoc['groupId'];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _bulanController.dispose();
    _nominalController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primaryNavy),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      if (!context.mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final finalDateTime = DateTime(
          pickedDate.year, pickedDate.month, pickedDate.day,
          pickedTime.hour, pickedTime.minute,
        );
        setState(() => selectedDateTime = finalDateTime);
      }
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDateTime == null) {
      _showSnackBar("Pilih deadline dulu!", Colors.redAccent);
      return;
    }
    if (myGroupId == null) return;

    setState(() => isSaving = true);
    try {
      final bulan = _bulanController.text.trim();
      final nominal = int.parse(_nominalController.text.replaceAll(',', ''));

      final check = await FirebaseFirestore.instance
          .collection('kas_deadline')
          .where('bulan', isEqualTo: bulan)
          .where('groupId', isEqualTo: myGroupId)
          .get();

      if (check.docs.isNotEmpty) {
        _showSnackBar("Sudah ada tagihan bulan ini!", Colors.orange);
        setState(() => isSaving = false);
        return;
      }

      await FirebaseFirestore.instance.collection('kas_deadline').add({
        'bulan': bulan,
        'nominal': nominal,
        'tanggal_deadline': Timestamp.fromDate(selectedDateTime!),
        'created_at': FieldValue.serverTimestamp(),
        'groupId': myGroupId,
      });

      setState(() {
        selectedDateTime = null;
        _bulanController.clear();
        isSaving = false;
      });
      _showSnackBar("Tagihan kas berhasil dikirim!", primaryNavy);
    } catch (e) {
      setState(() => isSaving = false);
      _showSnackBar("Error: $e", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: primaryNavy)));
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryNavy,
        title: const Text("Pengaturan Kas", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Curved Header Background
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: primaryNavy,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
          ),

          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                
                // Form Input Tagihan
                _buildFormCard(),

                const SizedBox(height: 30),
                const Text("Daftar Tagihan Aktif", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 15),
                _buildList(),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildStyledTextField(
              controller: _bulanController,
              label: "Bulan Iuran",
              hint: "Misal: April 2024",
              icon: Icons.calendar_today_rounded,
            ),
            const SizedBox(height: 15),
            _buildStyledTextField(
              controller: _nominalController,
              label: "Nominal Kas (Rp)",
              icon: Icons.account_balance_wallet_rounded,
              isNumber: true,
            ),
            const SizedBox(height: 15),
            
            // Deadline Picker
            GestureDetector(
              onTap: () => _selectDateTime(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_available_rounded, color: primaryNavy),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        selectedDateTime == null
                            ? "Atur Batas Waktu (Deadline)"
                            : DateFormat('dd MMM yyyy, HH:mm').format(selectedDateTime!),
                        style: TextStyle(color: selectedDateTime == null ? Colors.grey[600] : Colors.black87, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: isSaving 
                ? Center(child: CircularProgressIndicator(color: primaryNavy))
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryNavy,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 0,
                    ),
                    onPressed: _saveSettings,
                    child: const Text("KIRIM TAGIHAN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly, ThousandsFormatter()] : [],
      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryNavy, size: 22),
        filled: true,
        fillColor: backgroundColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('kas_deadline')
          .where('groupId', isEqualTo: myGroupId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("Belum ada tagihan aktif."));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (c, i) {
            final d = docs[i];
            final dl = (d['tanggal_deadline'] as Timestamp).toDate();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: primaryNavy.withOpacity(0.1),
                  child: Icon(Icons.receipt_long_rounded, color: primaryNavy, size: 20),
                ),
                title: Text(d['bulan'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("Batas: ${DateFormat('dd MMM yyyy').format(dl)}", style: const TextStyle(fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(d.reference),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(DocumentReference ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Hapus Tagihan?"),
        content: const Text("Tindakan ini tidak dapat dibatalkan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          TextButton(onPressed: () { ref.delete(); Navigator.pop(context); }, child: const Text("Hapus", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(oldValue, newValue) {
    if (newValue.text.isEmpty) return newValue;
    final value = int.parse(newValue.text.replaceAll(',', ''));
    final newText = NumberFormat('#,###').format(value);
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}