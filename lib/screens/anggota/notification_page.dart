// lib/screens/anggota/notification_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

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
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _currentUid = user.uid;
          _userGroupId = userDoc['groupId'];
          // 🔥 KUNCI UNIK: UID
          lastRead = prefs.getInt('last_read_$_currentUid') ?? 0;
          _isLoadingUser = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0, backgroundColor: primaryNavy,
        title: const Text("Notifikasi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true, iconTheme: const IconThemeData(color: Colors.white),
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
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return Center(child: CircularProgressIndicator(color: primaryNavy));
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) return const Center(child: Text("Belum ada notifikasi"));

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final tanggal = data['tanggal'] as Timestamp? ?? Timestamp.now();
                      final judul = data['judul'] ?? "Notifikasi";
                      final isi = data['pesan'] ?? "";
                      
                      // Cek status baca berdasarkan waktu simpan di HP
                      final sudahDibaca = tanggal.millisecondsSinceEpoch <= lastRead;

                      return _buildNotificationCard(judul, isi, tanggal.toDate(), sudahDibaca);
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
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Garis merah penanda belum dibaca
              Container(width: 5, color: sudahDibaca ? Colors.transparent : Colors.redAccent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(judul, style: TextStyle(fontWeight: sudahDibaca ? FontWeight.w600 : FontWeight.bold, fontSize: 15, color: primaryNavy)),
                          if (!sudahDibaca) const CircleAvatar(radius: 4, backgroundColor: Colors.redAccent),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(isi, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4)),
                      const SizedBox(height: 10),
                      Text(DateFormat("dd MMM, HH:mm").format(tgl), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
}