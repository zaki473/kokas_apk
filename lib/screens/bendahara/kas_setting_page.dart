import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class KasSettingPage extends StatefulWidget {
  const KasSettingPage({super.key});

  @override
  State<KasSettingPage> createState() => _KasSettingPageState();
}

class _KasSettingPageState extends State<KasSettingPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _bulanController = TextEditingController();
  final TextEditingController _nominalController = TextEditingController(text: "10000");
  
  DateTime? selectedDateTime;
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bulanController.dispose();
    _nominalController.dispose();
    super.dispose();
  }

  // Fungsi Format Rupiah
  String formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF1A237E)),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      if (!context.mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        DateTime finalDateTime = DateTime(
          pickedDate.year, pickedDate.month, pickedDate.day,
          pickedTime.hour, pickedTime.minute,
        );

        if (finalDateTime.isBefore(DateTime.now())) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Waktu tidak boleh di masa lalu!"), backgroundColor: Colors.orange),
          );
          return;
        }
        setState(() => selectedDateTime = finalDateTime);
      }
    }
  }

  void _saveSettings() async {
  if (_formKey.currentState!.validate()) {
    if (selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih Batas Waktu Terlebih Dahulu!"), backgroundColor: Colors.red),
      );
      return;
    }

    // Tampilkan loading agar user tidak tekan tombol berkali-kali
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final bulanInput = _bulanController.text.trim();

      // --- VALIDASI: CEK APAKAH BULAN SUDAH ADA ---
      final checkExist = await FirebaseFirestore.instance
          .collection('kas_deadline')
          .where('bulan', isEqualTo: bulanInput)
          .get();

      if (checkExist.docs.isNotEmpty) {
        if (!mounted) return;
        Navigator.pop(context); // Tutup loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Tagihan untuk '$bulanInput' sudah ada! Gunakan nama lain atau hapus yang lama."), 
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // --- SIMPAN JIKA BELUM ADA ---
      await FirebaseFirestore.instance.collection('kas_deadline').add({
        'bulan': bulanInput,
        'nominal': int.parse(_nominalController.text.replaceAll('.', '')),
        'tanggal_deadline': Timestamp.fromDate(selectedDateTime!),
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context); // Tutup loading
      
      setState(() {
        selectedDateTime = null;
        _bulanController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Tagihan Berhasil Dikirim ke Anggota!"), 
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Tutup loading
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        title: const Text("Kirim Tagihan Kas", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Container(
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- JAM DIGITAL WIDGET ---
                _buildLiveClock(),

                const SizedBox(height: 25),
                
                // --- FORM INPUT ---
                _buildInputForm(),

                const SizedBox(height: 35),

                // --- DAFTAR TAGIHAN AKTIF ---
                const Row(
                  children: [
                    Icon(Icons.history_rounded, color: Color(0xFF1A237E), size: 20),
                    SizedBox(width: 8),
                    Text("Riwayat Tagihan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                  ],
                ),
                const SizedBox(height: 15),
                _buildTagihanList(),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveClock() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Waktu Server", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(DateFormat('dd MMMM yyyy').format(_now), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          Text(
            DateFormat('HH:mm:ss').format(_now),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(
            controller: _bulanController,
            label: "Untuk Bulan",
            hint: "Contoh: Januari 2024",
            icon: Icons.calendar_month_outlined,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            controller: _nominalController,
            label: "Nominal Iuran",
            hint: "10000",
            icon: Icons.payments_outlined,
            isNumber: true,
            prefix: "Rp ",
          ),
          const SizedBox(height: 15),
          
          // Deadline Selector
          InkWell(
            onTap: () => _selectDateTime(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selectedDateTime != null ? const Color(0xFF1A237E) : Colors.transparent),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: selectedDateTime != null ? const Color(0xFF1A237E) : Colors.grey),
                  const SizedBox(width: 15),
                  Text(
                    selectedDateTime == null 
                      ? "Pilih Batas Waktu (Deadline)" 
                      : DateFormat('dd MMM yyyy, HH:mm').format(selectedDateTime!),
                    style: TextStyle(
                      color: selectedDateTime == null ? Colors.grey[600] : Colors.black,
                      fontWeight: selectedDateTime == null ? FontWeight.normal : FontWeight.bold
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 5,
              ),
              onPressed: _saveSettings,
              child: const Text("KIRIM TAGIHAN MASSAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    String? prefix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: (v) => v!.isEmpty ? "Harus diisi" : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefix,
          prefixIcon: Icon(icon, color: const Color(0xFF1A237E)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTagihanList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('kas_deadline').orderBy('tanggal_deadline', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Belum ada tagihan aktif."));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            DateTime dl = (doc['tanggal_deadline'] as Timestamp).toDate();
            bool isOver = _now.isAfter(dl);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isOver ? Colors.grey[200]! : Colors.green[100]!),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isOver ? Colors.grey[100] : Colors.green[50],
                  child: Icon(isOver ? Icons.history_rounded : Icons.notifications_active, color: isOver ? Colors.grey : Colors.green),
                ),
                title: Text("Bulan ${doc['bulan']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Batas: ${DateFormat('dd MMM, HH:mm').format(dl)}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _showDeleteConfirm(doc.reference),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirm(DocumentReference ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hapus Tagihan?"),
        content: const Text("Anggota tidak akan lagi melihat tagihan ini di dashboard mereka."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          TextButton(onPressed: () { ref.delete(); Navigator.pop(context); }, child: const Text("Hapus", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}