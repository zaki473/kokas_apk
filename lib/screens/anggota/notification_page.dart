import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '/services/error_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final Color primaryNavy = const Color(0xFF1A237E);
  final Color backgroundColor = const Color(0xFFF4F6F8);
  
  String? _userGroupId;
  String? _currentUid; 
  bool _isLoadingUser = true;
  int lastRead = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && mounted) {
          setState(() {
            _currentUid = user.uid;
            _userGroupId = userDoc['groupId'];
            // Ambil waktu terakhir kali buka notif
            lastRead = prefs.getInt('last_read_${user.uid}') ?? 0;
            _isLoadingUser = false;
          });
          // Update waktu baca sekarang agar saat buka berikutnya tidak merah lagi
          _updateLastRead();
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ErrorService.show(context, e);
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  Future<void> _updateLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentUid != null) {
      // Simpan waktu sekarang sebagai titik acuan "sudah dibaca"
      await prefs.setInt('last_read_$_currentUid', DateTime.now().millisecondsSinceEpoch);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0, 
        backgroundColor: primaryNavy,
        title: const Text("Notifikasi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        centerTitle: true, 
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingUser 
        ? Center(child: CircularProgressIndicator(color: primaryNavy))
        : _userGroupId == null || _userGroupId!.isEmpty
          ? _buildNoGroupState() // Cegah query jika user belum punya grup
          : Stack(
              children:[
                // Background biru di atas
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: primaryNavy,
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('announcements')
                      .where('groupId', isEqualTo: _userGroupId)
                      .orderBy('tanggal', descending: true)
                      .limit(30) // Batasi agar ringan
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) return _buildErrorState(snap.error.toString());
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) return _buildEmptyState();

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final Timestamp tanggalTs = data['tanggal'] as Timestamp? ?? Timestamp.now();
                        final String judul = data['judul'] ?? "Pesan Baru";
                        final String isi = data['pesan'] ?? "";
                        
                        // Cek status berdasarkan timestamp Firestore vs SharedPreferences
                        final bool sudahDibaca = tanggalTs.millisecondsSinceEpoch <= lastRead;

                        return _buildNotificationCard(judul, isi, tanggalTs.toDate(), sudahDibaca);
                      },
                    );
                  },
                ),
              ],
            ),
    );
  }

  // --- FIX OVERFLOW & PERFORMA: Ganti IntrinsicHeight dengan Border Side ---
  Widget _buildNotificationCard(String judul, String isi, DateTime tgl, bool sudahDibaca) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(18),
        boxShadow:[
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          // Gunakan Border kiri sebagai penanda warna (merah = belum dibaca)
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: sudahDibaca ? Colors.transparent : Colors.redAccent,
                width: 5,
              ),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:[
              // Header Judul dan Dot Merah
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:[
                  // Expanded agar teks panjang bisa wrap/titik-titik dan tidak nabrak
                  Expanded(
                    child: Text(
                      judul, 
                      style: TextStyle(
                        fontWeight: sudahDibaca ? FontWeight.w600 : FontWeight.bold, 
                        fontSize: 15, 
                        color: primaryNavy
                      ),
                      maxLines: 2, // Maksimal 2 baris agar rapi
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!sudahDibaca) ...[
                    const SizedBox(width: 10),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              
              // Isi Pesan (Biarkan mengalir ke bawah secara natural sesuai panjang teks)
              Text(
                isi, 
                style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
              ),
              const SizedBox(height: 12),
              
              // Waktu
              Row(
                children:[
                  Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 5),
                  Text(
                    DateFormat("dd MMM yyyy, HH:mm").format(tgl), 
                    style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)
                  ),
                ],
              ),
            ],
          ),
        ),
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
            "Anda belum tergabung di grup mana pun.",
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children:[
          Icon(Icons.notifications_off_rounded, size: 80, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 15),
          const Text(
            "Belum ada pengumuman baru.", 
            style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children:[
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
            const SizedBox(height: 15),
            const Text("Oops! Terjadi kesalahan.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              error.contains("index") 
                ? "Database memerlukan sinkronisasi indeks. Hubungi admin." 
                : "Gagal memuat pengumuman.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}