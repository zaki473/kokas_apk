import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PengumumanPage extends StatefulWidget {
  const PengumumanPage({super.key});

  @override
  State<PengumumanPage> createState() => _PengumumanPageState();
}

class _PengumumanPageState extends State<PengumumanPage> {
  final _controller = TextEditingController();
  bool _isSending = false;

  void _kirimPengumuman() async {
    if (_controller.text.isEmpty) return;

    setState(() => _isSending = true);
    await FirebaseFirestore.instance.collection('announcements').add({
      'pesan': _controller.text,
      'tanggal': DateTime.now(),
      'author': 'Bendahara',
    });

    _controller.clear();
    setState(() => _isSending = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pengumuman Terkirim!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pengumuman"), backgroundColor: Colors.amber[700]),
      body: Column(
        children: [
          // Input Pengumuman
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Tulis pengumuman...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _isSending ? null : _kirimPengumuman,
                  icon: Icon(Icons.send, color: Colors.amber[700]),
                )
              ],
            ),
          ),
          const Divider(),
          // List Pengumuman yang sudah ada
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('announcements').orderBy('tanggal', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var data = snapshot.data!.docs[index];
                    String tgl = DateFormat('dd MMM yyyy, HH:mm').format(data['tanggal'].toDate());
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      child: ListTile(
                        title: Text(data['pesan']),
                        subtitle: Text(tgl, style: const TextStyle(fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => FirebaseFirestore.instance.collection('announcements').doc(data.id).delete(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}