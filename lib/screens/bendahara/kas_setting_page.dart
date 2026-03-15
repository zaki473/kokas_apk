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
  DateTime? selectedDateTime;
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
        // Gabungkan tanggal dan jam
        DateTime finalDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // VALIDASI: Jangan biarkan memilih waktu yang sudah lewat dari SEKARANG
        if (finalDateTime.isBefore(DateTime.now())) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Waktu tidak boleh di masa lalu!"), backgroundColor: Colors.orange),
          );
          return;
        }

        setState(() {
          selectedDateTime = finalDateTime;
        });
      }
    }
  }

  void _saveSettings() async {
    if (selectedDateTime == null) return;

    try {
      // Tambahkan konfirmasi sebelum simpan
      final batch = FirebaseFirestore.instance.batch();

      var settingRef = FirebaseFirestore.instance.collection('settings').doc('kas_deadline');
      batch.set(settingRef, {
        'tanggal': Timestamp.fromDate(selectedDateTime!), // Simpan sebagai Timestamp resmi
        'last_updated': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Deadline Berhasil Diupdate!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setting Kas"), backgroundColor: Colors.amber[700]),
      body: Column(
        children: [
          // Tampilan Jam Sekarang
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text("Waktu HP Kamu Sekarang:"),
                Text(
                  DateFormat('HH:mm:ss').format(_now),
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  tileColor: Colors.amber[50],
                  title: Text(selectedDateTime == null 
                    ? "Pilih Deadline" 
                    : DateFormat('dd MMM yyyy, HH:mm', 'id').format(selectedDateTime!)),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () => _selectDateTime(context),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: selectedDateTime != null ? _saveSettings : null,
                  child: const Text("SIMPAN DEADLINE"),
                )
              ],
            ),
          ),

          const Divider(),

          // Monitor Real-time dari Firestore
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('settings').doc('kas_deadline').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text("Belum ada deadline aktif."));
                }

                var data = snapshot.data!.data() as Map<String, dynamic>;
                // .toDate().toLocal() sangat penting untuk menghindari selisih jam timezone
                DateTime deadline = (data['tanggal'] as Timestamp).toDate().toLocal();

                // Perbandingan: kita bulankan ke detik agar lebih adil
                bool isOver = _now.isAfter(deadline);

                if (isOver) {
                  return const Center(
                    child: Text("DEADLINE TELAH BERAKHIR", 
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                  );
                }

                Duration sisa = deadline.difference(_now);
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("DEADLINE AKTIF:"),
                      Text(DateFormat('dd MMMM yyyy, HH:mm', 'id').format(deadline), 
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      const Text("SISA WAKTU:"),
                      Text(
                        "${sisa.inDays} Hari ${sisa.inHours % 24} Jam ${sisa.inMinutes % 60} Menit ${sisa.inSeconds % 60} Detik",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}