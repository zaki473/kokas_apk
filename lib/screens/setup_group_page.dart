import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/error_service.dart'; // 🔥 IMPORT ERROR SERVICE DI SINI
import 'login_screen.dart';
import 'bendahara_screen.dart';
import 'anggota_screen.dart';

class SetupGroupPage extends StatefulWidget {
  const SetupGroupPage({super.key});

  @override
  State<SetupGroupPage> createState() => _SetupGroupPageState();
}

class _SetupGroupPageState extends State<SetupGroupPage> {
  final _groupNameController = TextEditingController();
  final _joinCodeController = TextEditingController();
  final String myUid = FirebaseAuth.instance.currentUser!.uid;

  final Color primaryNavy = const Color(0xFF1A237E);
  final Color secondaryTeal = const Color(0xFF00796B);

  @override
  void dispose() {
    _groupNameController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  // --- LOGIKA UTAMA ---

  void _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) return;

    _showLoading();
    try {
      // 1. Buat dokumen grup baru
      await FirebaseFirestore.instance.collection('groups').doc(myUid).set({
        'name': groupName,
        'createdBy': myUid,
        'createdAt': FieldValue.serverTimestamp(),
        'members': [myUid],
      });

      // 2. Update data user menjadi bendahara
      await FirebaseFirestore.instance.collection('users').doc(myUid).update({
        'role': 'bendahara',
        'groupId': myUid,
      });

      if (!mounted) return;
      Navigator.pop(context); // Tutup loading

      // 🔥 TAMPILKAN POP-UP SUKSES
      await ErrorService.showSuccess(
        context, 
        "Hore! Grup '$groupName' berhasil dibuat. Silakan kelola kas Anda."
      );

      if (!mounted) return;
      _goToDashboard('bendahara');
    } catch (e) {
      if (mounted) Navigator.pop(context); // Tutup loading
      
      // 🔥 TAMPILKAN POP-UP ERROR (Langsung lempar 'e' agar diterjemahkan ErrorService)
      ErrorService.show(context, e);
    }
  }

  void _joinGroup() async {
    String code = _joinCodeController.text.trim();
    if (code.isEmpty) return;

    _showLoading();
    try {
      var groupDoc = await FirebaseFirestore.instance.collection('groups').doc(code).get();

      if (groupDoc.exists) {
        // Update user
        await FirebaseFirestore.instance.collection('users').doc(myUid).update({
          'role': 'anggota',
          'groupId': code,
        });

        // Tambahkan ke list members di grup
        await FirebaseFirestore.instance.collection('groups').doc(code).update({
          'members': FieldValue.arrayUnion([myUid]),
        });

        if (!mounted) return;
        Navigator.pop(context); // Tutup loading

        // 🔥 TAMPILKAN POP-UP SUKSES
        await ErrorService.showSuccess(
          context, 
          "Berhasil bergabung ke grup! Sekarang kamu bisa melihat kas bersama."
        );

        if (!mounted) return;
        _goToDashboard('anggota');
      } else {
        if (mounted) {
          Navigator.pop(context); // Tutup loading
          
          // 🔥 TAMPILKAN POP-UP ERROR MANUAL
          ErrorService.show(context, "Kode Grup tidak ditemukan! Pastikan kode yang dimasukkan benar.");
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Tutup loading

      // 🔥 TAMPILKAN POP-UP ERROR
      ErrorService.show(context, e);
    }
  }

  void _goToDashboard(String role) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => role == 'bendahara' ? const BendaharaScreen() : const AnggotaScreen()),
      (route) => false, // Bersihkan semua history page sebelumnya
    );
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBackButton(),
              const SizedBox(height: 50),
              const Text(
                "Langkah Terakhir!",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1A237E), letterSpacing: -0.5),
              ),
              const SizedBox(height: 12),
              Text(
                "Pilih peran Anda untuk mulai mengelola atau membayar iuran grup dengan transparan.",
                style: TextStyle(fontSize: 15, color: Colors.blueGrey[600], height: 1.5),
              ),
              const SizedBox(height: 45),

              _buildChoiceCard(
                title: "Saya Bendahara",
                subtitle: "Buat grup baru, kelola tagihan, dan pantau pengeluaran kas.",
                icon: Icons.admin_panel_settings_rounded,
                color: primaryNavy,
                onTap: () => _showDialogInput(
                  "Buat Grup Baru",
                  "Nama Grup (Misal: Kas Angkatan 22)",
                  _groupNameController,
                  _createGroup,
                ),
              ),

              const SizedBox(height: 20),

              _buildChoiceCard(
                title: "Saya Anggota",
                subtitle: "Masuk ke grup teman/organisasi Anda menggunakan kode unik.",
                icon: Icons.group_add_rounded,
                color: secondaryTeal,
                onTap: () => _showDialogInput(
                  "Gabung ke Grup",
                  "Masukkan Kode Grup dari Bendahara",
                  _joinCodeController,
                  _joinGroup,
                ),
              ),
              
              const SizedBox(height: 40),
              Center(
                child: Text(
                  "Butuh bantuan? Hubungi admin sistem.",
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return InkWell(
      onTap: () async {
        await AuthService().signOut();
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.logout_rounded, size: 18, color: Colors.red[400]),
            const SizedBox(width: 8),
            Text("Logout", style: TextStyle(color: Colors.red[400], fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Color(0xFF2D3142))),
                      const SizedBox(height: 6),
                      Text(subtitle, style: TextStyle(fontSize: 12.5, color: Colors.blueGrey[400], height: 1.3)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[300], size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDialogInput(String title, String hint, TextEditingController controller, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Batal", style: TextStyle(color: Colors.grey[600]))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryNavy,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text("Lanjutkan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: primaryNavy, strokeWidth: 5)),
    );
  }
}