import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E), // Navy Theme
        title: const Text("Pengumuman KOKAS", 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background Header Navy
          Container(
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .orderBy('tanggal', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var data = snapshot.data!.docs[index];
                  String tgl = DateFormat('dd MMM yyyy, HH:mm').format(data['tanggal'].toDate());

                  return _buildAnnouncementCard(data['pesan'], tgl);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // WIDGET KARTU PENGUMUMAN (NEWS FEED STYLE)
  Widget _buildAnnouncementCard(String pesan, String tanggal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.campaign_rounded, 
                  color: Color(0xFF1A237E), size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                "Info Bendahara",
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 14, 
                  color: Color(0xFF1A237E)
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            pesan,
            style: const TextStyle(
              fontSize: 15, 
              color: Color(0xFF2D3142), 
              height: 1.5 // Memberikan jarak antar baris agar nyaman dibaca
            ),
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 5),
              Text(
                tanggal,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TAMPILAN JIKA TIDAK ADA PENGUMUMAN
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.speaker_notes_off_rounded, 
            size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text(
            "Belum ada pengumuman terbaru",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}