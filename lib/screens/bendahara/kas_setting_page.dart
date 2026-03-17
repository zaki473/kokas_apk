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
  // Controller baru untuk Bulan dan Nominal
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

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
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

  // FUNGSI SIMPAN TAGIHAN BARU
  void _saveSettings() async {
    if (selectedDateTime == null || _bulanController.text.isEmpty || _nominalController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lengkapi semua data!"), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      // Simpan ke koleksi 'kas_deadline' agar muncul di list Anggota
      await FirebaseFirestore.instance.collection('kas_deadline').add({
        'bulan': _bulanController.text,
        'nominal': int.parse(_nominalController.text),
        'tanggal_deadline': Timestamp.fromDate(selectedDateTime!),
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        selectedDateTime = null;
        _bulanController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tagihan Kas Berhasil Dikirim ke Anggota!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kirim Tagihan Kas"), backgroundColor: Colors.amber[700]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // JAM SEKARANG
            Text("Waktu Sekarang: ${DateFormat('HH:mm:ss').format(_now)}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // INPUT FORM
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _bulanController,
                      decoration: const InputDecoration(labelText: "Untuk Pembayaran Bulan (Contoh: Januari 2024)", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _nominalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Nominal Kas (Rp)", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 15),
                    ListTile(
                      tileColor: Colors.amber[50],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      title: Text(selectedDateTime == null 
                        ? "Pilih Batas Waktu (Deadline)" 
                        : DateFormat('dd MMM yyyy, HH:mm').format(selectedDateTime!)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () => _selectDateTime(context),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], foregroundColor: Colors.white),
                        onPressed: _saveSettings,
                        child: const Text("KIRIM TAGIHAN KE ANGGOTA"),
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Divider(),
            const Text("DAFTAR TAGIHAN AKTIF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            // LIST MONITORING TAGIHAN YANG SUDAH DIBUAT
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('kas_deadline').orderBy('tanggal_deadline', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                if (snapshot.data!.docs.isEmpty) return const Text("Belum ada data.");

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    DateTime dl = (doc['tanggal_deadline'] as Timestamp).toDate();
                    bool isOver = _now.isAfter(dl);

                    return Card(
                      color: isOver ? Colors.grey[300] : Colors.green[50],
                      child: ListTile(
                        title: Text("Bulan: ${doc['bulan']}"),
                        subtitle: Text("Batas: ${DateFormat('dd MMM, HH:mm').format(dl)}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => doc.reference.delete(), // Bendahara bisa hapus tagihan
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}