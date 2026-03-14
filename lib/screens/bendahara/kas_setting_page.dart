import 'dart:async'; // Tambahkan ini untuk Timer
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class KasSettingPage extends StatefulWidget {
  const KasSettingPage({super.key});

  @override
  State<KasSettingPage> createState() => _KasSettingPageState();
}

class _KasSettingPageState extends State<KasSettingPage> {
  DateTime? selectedDateTime; // Diganti dari selectedDate
  Timer? _timer; // Timer untuk update detik real-time
  DateTime _now = DateTime.now(); // Waktu sekarang yang terus update

  @override
  void initState() {
    super.initState();
    // Jalankan timer setiap 1 detik untuk mengupdate UI
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
    _timer?.cancel(); // Hentikan timer saat keluar halaman
    super.dispose();
  }

  // FUNGSI PILIH TANGGAL + JAM
  Future<void> _selectDateTime(BuildContext context) async {
    // 1. Pilih Tanggal
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      // 2. Pilih Jam
      if (!context.mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          // Gabungkan Tanggal dan Jam
          selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _saveSettings() async {
    if (selectedDateTime == null) return;

    final batch = FirebaseFirestore.instance.batch();

    var settingRef = FirebaseFirestore.instance.collection('settings').doc('kas_deadline');
    batch.set(settingRef, {
      'tanggal': selectedDateTime, // Simpan DateTime lengkap (Tgl + Jam)
      'last_updated': DateTime.now(),
    });

    var historyRef = FirebaseFirestore.instance.collection('kas_history').doc();
    batch.set(historyRef, {
      'tanggal_kas': selectedDateTime,
      'dibuat_pada': DateTime.now(),
    });

    await batch.commit();

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Deadline Berhasil Diatur!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Setting Kas & Waktu"),
        backgroundColor: Colors.amber[700],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // TAMPILAN WAKTU REAL-TIME SEKARANG
                Text(
                  "Waktu Sekarang: ${DateFormat('HH:mm:ss').format(_now)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 20),
                const Text("Tentukan Batas Akhir Pembayaran Kas:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                
                ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Colors.amber),
                  ),
                  title: Text(
                    selectedDateTime == null
                        ? "Pilih Tanggal & Jam"
                        : DateFormat('dd MMMM yyyy, HH:mm', 'id').format(selectedDateTime!),
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () => _selectDateTime(context),
                ),
                
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: selectedDateTime != null ? _saveSettings : null,
                  child: const Text("SIMPAN & UMUMKAN"),
                ),
              ],
            ),
          ),
          const Divider(thickness: 2),
          const Text("Status Deadline Aktif", style: TextStyle(fontWeight: FontWeight.bold)),
          
          // STREAM UNTUK CEK DEADLINE SECARA REAL-TIME
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('settings').doc('kas_deadline').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
              
              var data = snapshot.data!.data() as Map<String, dynamic>;
              DateTime deadline = (data['tanggal'] as Timestamp).toDate();

              // LOGIKA HILANG OTOMATIS: Jika waktu sekarang sudah melewati deadline
              if (_now.isAfter(deadline)) {
                return const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text("DEADLINE SUDAH BERAKHIR", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                );
              }

              // Hitung Sisa Waktu
              Duration sisa = deadline.difference(_now);
              String sisaWaktu = "${sisa.inDays}h ${sisa.inHours % 24}m ${sisa.inMinutes % 60}s ${sisa.inSeconds % 60}s";

              return Card(
                color: Colors.green[50],
                margin: const EdgeInsets.all(15),
                child: ListTile(
                  title: Text("Sisa Waktu: $sisaWaktu", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  subtitle: Text("Sampai: ${DateFormat('dd MMM yyyy, HH:mm:ss').format(deadline)}"),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}