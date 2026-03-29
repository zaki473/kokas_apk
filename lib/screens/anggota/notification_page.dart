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
            lastRead = prefs.getInt('last_read_${user.uid}') ?? 0;
            _isLoadingUser = false;
          });
          _updateLastRead();
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ErrorService.show(context, e);
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
        title: const Text("Notifikasi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true, 
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingUser 
        ? Center(child: CircularProgressIndicator(color: primaryNavy))
        : Stack(
            children: [
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
                    .limit(30) // Batasi agar tidak berat
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) return _buildErrorState();
                  if (!snap.hasData) return Center(child: CircularProgressIndicator(color: primaryNavy));
                  
                  final docs = snap.data!.docs;
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

  Widget _buildNotificationCard(String judul, String isi, DateTime tgl, bool sudahDibaca) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Indikator status baca
              Container(
                width: 6, 
                color: sudahDibaca ? Colors.transparent : Colors.redAccent,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              judul, 
                              style: TextStyle(
                                fontWeight: sudahDibaca ? FontWeight.w600 : FontWeight.bold, 
                                fontSize: 14, 
                                color: primaryNavy
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!sudahDibaca) 
                            const Icon(Icons.circle, size: 8, color: Colors.redAccent),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isi, 
                        style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4)
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat("dd MMM yyyy, HH:mm").format(tgl), 
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text("Belum ada notifikasi baru.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text("Gagal memuat notifikasi. Pastikan database sudah terindeks.", textAlign: TextAlign.center),
      ),
    );
  }
}