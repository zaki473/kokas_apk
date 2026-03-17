import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatusAnggotaPage extends StatefulWidget {
  const StatusAnggotaPage({super.key});

  @override
  State<StatusAnggotaPage> createState() => _StatusAnggotaPageState();
}

class _StatusAnggotaPageState extends State<StatusAnggotaPage> {
  String? _selectedBulan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monitoring Kas Anggota"),
        backgroundColor: Colors.amber[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. DROPDOWN PILIH BULAN (FIX OVERFLOW)
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('kas_deadline').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                
                var docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Text("Belum ada daftar tagihan.");

                if (_selectedBulan == null && docs.isNotEmpty) {
                  _selectedBulan = docs.first['bulan'];
                }

                return DropdownButtonFormField<String>(
                  isExpanded: true, // SOLUSI: Agar dropdown fleksibel mengikuti lebar layar
                  value: _selectedBulan,
                  decoration: const InputDecoration(
                    labelText: "Pilih Bulan Monitoring",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_month),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  // Menangani tampilan teks yang terpilih agar tidak overflow
                  selectedItemBuilder: (BuildContext context) {
                    return docs.map<Widget>((doc) {
                      return Text(
                        doc['bulan'],
                        overflow: TextOverflow.ellipsis, // Jika sangat panjang akan jadi "Text Panjan..."
                        maxLines: 1,
                      );
                    }).toList();
                  },
                  items: docs.map((d) {
                    return DropdownMenuItem(
                      value: d['bulan'].toString(),
                      child: Text(
                        d['bulan'],
                        softWrap: true, // Agar di dalam menu pilihan teks bisa turun ke bawah jika panjang
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedBulan = val),
                );
              },
            ),
          ),

          const Divider(thickness: 1, height: 1),

          // 2. LIST SEMUA ANGGOTA DAN STATUSNYA
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'anggota')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Tidak ada data anggota."));

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  padding: const EdgeInsets.only(top: 10),
                  itemBuilder: (context, index) {
                    var user = snapshot.data!.docs[index];
                    String uid = user.id;
                    String nama = user['email']; 

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('pembayaran')
                          .doc("${uid}_$_selectedBulan")
                          .snapshots(),
                      builder: (context, paySnap) {
                        String status = "Belum Bayar";
                        Color statusColor = Colors.red;
                        IconData icon = Icons.cancel;

                        if (paySnap.hasData && paySnap.data!.exists) {
                          String s = paySnap.data!['status'];
                          if (s == 'disetujui') {
                            status = "Lunas";
                            statusColor = Colors.green;
                            icon = Icons.check_circle;
                          } else if (s == 'pending') {
                            status = "Pending";
                            statusColor = Colors.orange;
                            icon = Icons.hourglass_empty;
                          } else if (s == 'ditolak') {
                            status = "Ditolak";
                            statusColor = Colors.redAccent;
                            icon = Icons.error_outline;
                          }
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                            leading: CircleAvatar(
                              backgroundColor: statusColor.withOpacity(0.1),
                              child: Icon(icon, color: statusColor),
                            ),
                            title: Text(
                              nama, 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text("Status: $status", style: TextStyle(color: statusColor, fontSize: 12)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status == "Lunas" ? "AMAN" : "TAGIH",
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}