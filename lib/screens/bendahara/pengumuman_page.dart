import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/error_service.dart';

class PengumumanPage extends StatefulWidget {
  const PengumumanPage({super.key});

  @override
  State<PengumumanPage> createState() => _PengumumanPageState();
}

class _PengumumanPageState extends State<PengumumanPage> {
  final _controller = TextEditingController();
  bool _isSending = false;
  String? _myGroupId;
  String _userName = "Bendahara"; // Default name
  bool _isLoadingInfo = true;

  // Optimasi: Simpan formatter di level class
  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    // WAJIB: Mencegah memory leak
    _controller.dispose();
    super.dispose();
  }

  // Ambil groupId dan Nama asli bendahara
  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _myGroupId = doc.data()?['groupId'];
          _userName = doc.data()?['name'] ?? "Bendahara";
          _isLoadingInfo = false;
        });
      }
    }
  }

  void _kirimPengumuman() async {
    String pesan = _controller.text.trim();
    if (pesan.isEmpty || _myGroupId == null) return;

    setState(() => _isSending = true);
    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'pesan': pesan,
        'tanggal': FieldValue.serverTimestamp(),
        'author': _userName, // Menggunakan nama asli bendahara
        'groupId': _myGroupId,
      });

      _controller.clear();
      if (mounted) {
        ErrorService.showSuccess(context, "Pengumuman berhasil disiarkan!");
      }
    } catch (e) {
      if (!context.mounted) return;
      ErrorService.show(context, e);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        title: const Text(
          "Broadcast Pengumuman",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingInfo
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
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
                    _buildInputSection(),
                    const SizedBox(height: 10),
                    Expanded(child: _buildAnnouncementList()),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
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
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.campaign_rounded, color: Colors.white),
              label: Text(
                _isSending ? "MENGIRIM..." : "SIARKAN SEKARANG",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .where('groupId', isEqualTo: _myGroupId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError){
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData){
          return const Center(child: CircularProgressIndicator());
        }

        // Sort manual (O(N log N)) di luar loop build
        List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
        docs.sort((a, b) {
          Timestamp tA = a['tanggal'] ?? Timestamp.now();
          Timestamp tB = b['tanggal'] ?? Timestamp.now();
          return tB.compareTo(tA);
        });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.speaker_notes_off_rounded,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 15),
                Text(
                  "Belum ada pengumuman",
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String tglStr = data['tanggal'] != null
                ? _dateFormat.format((data['tanggal'] as Timestamp).toDate())
                : "...";

            return _buildAnnouncementCard(
              docs[index].id,
              data['pesan'] ?? "",
              tglStr,
              data['author'] ?? "Bendahara",
            );
          },
        );
      },
    );
  }

  Widget _buildAnnouncementCard(
    String id,
    String pesan,
    String tanggal,
    String author,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
                  const Icon(
                    Icons.account_circle,
                    size: 20,
                    color: Color(0xFF1A237E),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    author,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: () => _showDeleteDialog(id),
              ),
            ],
          ),
          const Divider(height: 25),
          Text(
            pesan,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF2D3142),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 5),
              Text(
                tanggal,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
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
        content: const Text(
          "Pesan ini akan dihapus dari dashboard semua anggota.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
            ),
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('announcements')
                  .doc(id)
                  .delete();
              Navigator.pop(context);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
