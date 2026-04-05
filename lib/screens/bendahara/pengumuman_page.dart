import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '/services/error_service.dart';
import '/services/fcm_service.dart';

class PengumumanPage extends StatefulWidget {
  const PengumumanPage({super.key});

  @override
  State<PengumumanPage> createState() => _PengumumanPageState();
}

class _PengumumanPageState extends State<PengumumanPage> {
  final _controller = TextEditingController();
  bool _isSending = false;
  String? _myGroupId;
  String _userName = "Bendahara";
  bool _isLoadingInfo = true;

  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');
  final Color primaryNavy = const Color(0xFF1A237E);

  @override
  void initState() {
    super.initState();
    _loadUserInfoAndSubscribe();
  }

  Future<void> _loadUserInfoAndSubscribe() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted && doc.exists) {
        _myGroupId = doc.data()?['groupId'];
        _userName = doc.data()?['name'] ?? "Bendahara";

        // ✅ Cek apakah bukan Web sebelum subscribeToTopic
        if (_myGroupId != null && !kIsWeb) {
          await FirebaseMessaging.instance
              .subscribeToTopic("group_$_myGroupId");
          debugPrint("Subscribed to topic: group_$_myGroupId");
        } else if (kIsWeb) {
          debugPrint("Web client: subscribeToTopic dilewati (tidak didukung).");
        }

        setState(() {
          _isLoadingInfo = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading user info: $e");
      if (mounted) setState(() => _isLoadingInfo = false);
    }
  }

  // Jangan lupa import di paling atas: 
// import '../services/fcm_service.dart';

void _kirimPengumuman() async {
  String pesan = _controller.text.trim();
  if (pesan.isEmpty) return;

  setState(() => _isSending = true);

  try {
    // Simpan ke Firestore (Kode aslimu)
    await FirebaseFirestore.instance.collection('announcements').add({
      'pesan': pesan,
      'tanggal': FieldValue.serverTimestamp(),
      'author': _userName,
      'groupId': _myGroupId,
    });

    // 🔥 TAMBAHKAN KODE INI UNTUK KIRIM NOTIFIKASI KE SEMUA ANGGOTA GRUP 🔥
    await FCMService.sendNotificationToGroup(
      groupId: _myGroupId!,
      title: "📢 Pengumuman dari $_userName",
      body: pesan,
    );

    _controller.clear();
    
    if (mounted) {
      FocusScope.of(context).unfocus();
      setState(() => _isSending = false);
      await ErrorService.showSuccess(context, "Pengumuman disiarkan & Notifikasi dikirim!");
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isSending = false);
      ErrorService.show(context, e);
    }
  }
}

  // 🔥 FUNGSI BARU UNTUK HAPUS PENGUMUMAN
  void _hapusPengumuman(String docId) async {
    // 1. Munculkan Dialog Konfirmasi (Agar tidak salah pencet)
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hapus Pengumuman?"),
        content: const Text("Pengumuman ini akan ditarik dan dihapus permanen dari grup."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Batal
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            onPressed: () => Navigator.pop(context, true), // Ya, Hapus
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    // 2. Jika user menekan batal, hentikan fungsi
    if (!confirmDelete) return;

    // 3. Proses penghapusan ke Firebase
    try {
      await FirebaseFirestore.instance.collection('announcements').doc(docId).delete();
      
      if (mounted) {
        await ErrorService.showSuccess(context, "Pengumuman berhasil dihapus!");
      }
    } catch (e) {
      if (mounted) {
        ErrorService.show(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: primaryNavy,
        elevation: 0,
        title: const Text(
          "Broadcast Pengumuman",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white), // Tombol back jadi putih
      ),
      body: _isLoadingInfo
          ? Center(child: CircularProgressIndicator(color: primaryNavy))
          : Column(
              children: [
                _buildInputSection(),
                const Divider(height: 1),
                Expanded(child: _buildAnnouncementList()),
              ],
            ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Tulis pengumuman untuk grup...",
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryNavy,
                foregroundColor: Colors.white,
                shape: (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)
                    ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    : RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isSending ? null : _kirimPengumuman,
              child: _isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text("SIARKAN SEKARANG", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAnnouncementList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .where('groupId', isEqualTo: _myGroupId)
          .orderBy('tanggal', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text("Terjadi kesalahan: ${snapshot.error}", style: const TextStyle(color: Colors.red)),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryNavy));
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text("Belum ada pengumuman di grup ini", style: TextStyle(color: Colors.grey[500])),
              ],
            )
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index]; // 👈 Ambil dokumennya
            final data = doc.data() as Map<String, dynamic>;
            final DateTime? date = (data['tanggal'] as Timestamp?)?.toDate();

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              shadowColor: Colors.black12,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  data['pesan'] ?? "",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Row(
                    children: [
                      Icon(Icons.person, size: 14, color: primaryNavy),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['author'] ?? 'Unknown',
                          style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        date != null ? _dateFormat.format(date) : "",
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // 🔥 TAMBAHAN TOMBOL HAPUS (TONG SAMPAH)
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () => _hapusPengumuman(doc.id), // Panggil fungsi hapus
                  tooltip: "Hapus Pengumuman",
                ),
              ),
            );
          },
        );
      },
    );
  }
}