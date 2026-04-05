import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/error_service.dart'; 

class KasSettingPage extends StatefulWidget {
  const KasSettingPage({super.key});

  @override
  State<KasSettingPage> createState() => _KasSettingPageState();
}

class _KasSettingPageState extends State<KasSettingPage> {
  final _formKey = GlobalKey<FormState>();
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

  String? _myGroupId;
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _bulanController = TextEditingController();
  // Standarisasi default value dengan format titik
  final TextEditingController _nominalController = TextEditingController(text: "10.000");

  DateTime? _selectedDateTime;

  final Color primaryNavy = const Color(0xFF1A237E);
  final Color backgroundColor = const Color(0xFFF4F6F8);

  @override
  void initState() {
    super.initState();
    _loadGroupId();
  }

  Future<void> _loadGroupId() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_myUid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _myGroupId = userDoc['groupId'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!context.mounted) return;
      ErrorService.show(context, e);
      if (mounted) setState(() => _isLoading = false);
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
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year, pickedDate.month, pickedDate.day,
            pickedTime.hour, pickedTime.minute,
          );
        });
      }
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDateTime == null) {
      _showSnackBar("Pilih deadline terlebih dahulu!", Colors.redAccent);
      return;
    }
    if (_myGroupId == null || _myGroupId!.isEmpty) {
      _showSnackBar("Anda tidak tergabung dalam grup kas aktif.", Colors.redAccent);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final bulan = _bulanController.text.trim();
      // Parsing aman dari format titik (.)
      final nominalStr = _nominalController.text.replaceAll('.', '');
      final nominal = int.tryParse(nominalStr) ?? 0;

      if (nominal <= 0) {
        _showSnackBar("Nominal kas tidak valid!", Colors.red);
        setState(() => _isSaving = false);
        return;
      }

      final check = await FirebaseFirestore.instance
          .collection('kas_deadline')
          .where('bulan', isEqualTo: bulan)
          .where('groupId', isEqualTo: _myGroupId)
          .get();

      if (check.docs.isNotEmpty) {
        if (!context.mounted) return;
        ErrorService.show(context, "Sudah ada tagihan aktif untuk bulan ini!");
        setState(() => _isSaving = false);
        return;
      }

      await FirebaseFirestore.instance.collection('kas_deadline').add({
        'bulan': bulan,
        'nominal': nominal,
        'tanggal_deadline': Timestamp.fromDate(_selectedDateTime!),
        'created_at': FieldValue.serverTimestamp(),
        'groupId': _myGroupId,
      });

      if (mounted) {
        setState(() {
          _selectedDateTime = null;
          _bulanController.clear();
          // Kita biarkan inputan nominal sesuai nilai terakhir agar Bendahara 
          // tidak perlu mengetik ulang nominal kas setiap bulan jika jumlahnya sama.
          _isSaving = false;
        });
        ErrorService.showSuccess(context, "Tagihan kas berhasil dikirim ke anggota!");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ErrorService.show(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryNavy,
        title: const Text("Pengaturan Kas", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryNavy))
          : _myGroupId == null || _myGroupId!.isEmpty
              ? _buildNoGroupState()
              : Stack(
                  children:[
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: primaryNavy,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(30), 
                          bottomRight: Radius.circular(30)
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:[
                          const SizedBox(height: 10),
                          _buildFormCard(),
                          const SizedBox(height: 35),
                          const Text(
                            "Daftar Tagihan Aktif", 
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))
                          ),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow:[BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children:[
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
            GestureDetector(
              onTap: () => _selectDateTime(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
                decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(15)),
                child: Row(
                  children:[
                    Icon(Icons.event_available_rounded, color: primaryNavy, size: 22),
                    const SizedBox(width: 12),
                    // Expanded agar jika format tanggal sangat panjang tidak overflow
                    Expanded(
                      child: Text(
                        _selectedDateTime == null
                            ? "Atur Batas Waktu (Deadline)"
                            : DateFormat('dd MMM yyyy, HH:mm').format(_selectedDateTime!),
                        style: TextStyle(
                          color: _selectedDateTime == null ? Colors.grey[600] : Colors.black87, 
                          fontSize: 14,
                          fontWeight: _selectedDateTime == null ? FontWeight.normal : FontWeight.w600
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55, // Fixed height agar tombol tidak berubah ukuran saat loading
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                onPressed: _isSaving ? null : _saveSettings,
                child: _isSaving 
                  ? const SizedBox(
                      height: 24, width: 24, 
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                    )
                  : const Text("KIRIM TAGIHAN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
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
      inputFormatters: isNumber 
          ? [FilteringTextInputFormatter.digitsOnly, ThousandsSeparatorFormatter()] 
          :[],
      validator: (v) => v!.isEmpty ? "Bidang ini wajib diisi" : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
        prefixIcon: Icon(icon, color: primaryNavy, size: 22),
        filled: true,
        fillColor: backgroundColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }

  // --- FIX OVERFLOW & TAMPILAN LIST ---
  Widget _buildList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('kas_deadline')
          .where('groupId', isEqualTo: _myGroupId)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snap) {
        // Penanganan error index firestore agar tidak layar merah
        if (snap.hasError) return _buildErrorState(snap.error.toString());
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final docs = snap.data?.docs ??[];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text("Belum ada tagihan aktif.", style: TextStyle(color: Colors.grey[500])),
            )
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (c, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final String docId = docs[i].id;
            
            final dlTimestamp = d['tanggal_deadline'] as Timestamp?;
            final dl = dlTimestamp?.toDate() ?? DateTime.now();
            final int nominal = d['nominal'] ?? 0;
            final String nominalStr = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(nominal);

            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow:[BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Row(
                children:[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryNavy.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.receipt_long_rounded, color: primaryNavy, size: 22),
                  ),
                  const SizedBox(width: 15),
                  // Expanded agar informasi teks terbagi dengan baik dan bebas overflow
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:[
                        Text(d['bulan'] ?? "-", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          "Kas: $nominalStr", 
                          style: TextStyle(fontSize: 13, color: Colors.green[700], fontWeight: FontWeight.w600)
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Batas: ${DateFormat('dd MMM yyyy').format(dl)}", 
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    ),
                    onPressed: () => _confirmDelete(FirebaseFirestore.instance.collection('kas_deadline').doc(docId)),
                  ),
                ],
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hapus Tagihan?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text("Tagihan ini akan dihapus dari daftar semua anggota. Tindakan ini tidak dapat dibatalkan."),
        actions:[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            onPressed: () { 
              ref.delete(); 
              Navigator.pop(context); 
            }, 
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoGroupState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children:[
          Icon(Icons.group_off_rounded, size: 80, color: Colors.grey),
          SizedBox(height: 15),
          Text(
            "Anda tidak terhubung dengan grup kas mana pun.",
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          error.contains("index") 
            ? "Memerlukan sinkronisasi Indeks Database. Hubungi Pengembang." 
            : "Gagal memuat daftar tagihan.",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ),
    );
  }
}

// --- FIX: Formatter Titik yang lebih aman dari crash ---
class ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    
    // Cegah crash jika ada karakter selain angka
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) return newValue;

    int value = int.parse(cleanText);
    final formatter = NumberFormat.decimalPattern('id'); // Menggunakan locale Indonesia
    final newString = formatter.format(value);
    
    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}