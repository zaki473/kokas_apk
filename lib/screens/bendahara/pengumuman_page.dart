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
    if (_controller.text.trim().isEmpty) return;

    setState(() => _isSending = true);
    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'pesan': _controller.text.trim(),
        'tanggal': DateTime.now(),
        'author': 'Bendahara',
      });

      _controller.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pengumuman berhasil disiarkan!"),
          backgroundColor: Colors.indigo,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal mengirim: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E), // Navy Dashboard
        title: const Text("Broadcast Pengumuman", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Navy Header
          Container(
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),

          Column(
            children: [
              // --- INPUT BOX ---
              _buildInputSection(),

              const SizedBox(height: 10),

              // --- LIST PENGUMUMAN ---
              Expanded(
                child: _buildAnnouncementList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // WIDGET INPUT PENGUMUMAN (PREMIUM BOX)
  Widget _buildInputSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Tulis pesan pengumuman ke semua anggota...",
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.all(15),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFF1A237E)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _kirimPengumuman,
              icon: _isSending 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.campaign_rounded, color: Colors.white),
              label: Text(
                _isSending ? "MENGIRIM..." : "SIARKAN SEKARANG",
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[800],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET STREAM LIST PENGUMUMAN
  Widget _buildAnnouncementList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('announcements').orderBy('tanggal', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.speaker_notes_off_rounded, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 15),
                Text("Belum ada pengumuman", style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            String tgl = DateFormat('dd MMM yyyy, HH:mm').format(data['tanggal'].toDate());

            return _buildAnnouncementCard(doc.id, data['pesan'], tgl);
          },
        );
      },
    );
  }

  // WIDGET CARD PENGUMUMAN ALA "NOTICE BOARD"
  Widget _buildAnnouncementCard(String id, String pesan, String tanggal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_circle, size: 20, color: Color(0xFF1A237E)),
                  const SizedBox(width: 8),
                  Text("Bendaraha KOKAS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800], fontSize: 13)),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                onPressed: () => _showDeleteDialog(id),
              ),
            ],
          ),
          const Divider(height: 25),
          Text(
            pesan,
            style: const TextStyle(fontSize: 15, color: Color(0xFF2D3142), height: 1.4),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 5),
              Text(
                tanggal,
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hapus Pengumuman?"),
        content: const Text("Pesan ini akan dihapus dari dashboard semua anggota."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, elevation: 0),
            onPressed: () {
              FirebaseFirestore.instance.collection('announcements').doc(id).delete();
              Navigator.pop(context);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}