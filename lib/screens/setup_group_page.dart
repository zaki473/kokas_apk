import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart'; // Sesuaikan path-nya
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

  // --- LOGIKA UTAMA (TETAP SAMA) ---

  void _createGroup() async {
    try {
      final groupName = _groupNameController.text.trim();
      if (groupName.isEmpty) return;

      _showLoading();

      await FirebaseFirestore.instance.collection('groups').doc(myUid).set({
        'name': groupName,
        'createdBy': myUid,
        'createdAt': FieldValue.serverTimestamp(),
        'members': [myUid],
      });

      await FirebaseFirestore.instance.collection('users').doc(myUid).update({
        'role': 'bendahara',
        'groupId': myUid,
      });

      if (!mounted) return;
      Navigator.pop(context); // Tutup loading
      _goToDashboard('bendahara');
    } catch (e) {
      Navigator.pop(context);
      _showError("Gagal membuat grup: $e");
    }
  }

  void _joinGroup() async {
    String code = _joinCodeController.text.trim();
    if (code.isEmpty) return;

    try {
      _showLoading();

      var groupDoc = await FirebaseFirestore.instance.collection('groups').doc(code).get();

      if (groupDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(myUid).update({
          'role': 'anggota',
          'groupId': code,
        });

        await FirebaseFirestore.instance.collection('groups').doc(code).update({
          'members': FieldValue.arrayUnion([myUid]),
        });

        if (!mounted) return;
        Navigator.pop(context); // Tutup loading
        _goToDashboard('anggota');
      } else {
        Navigator.pop(context);
        _showError("Kode Grup tidak valid!");
      }
    } catch (e) {
      Navigator.pop(context);
      _showError("Gagal bergabung: $e");
    }
  }

  void _goToDashboard(String role) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => role == 'bendahara' ? const BendaharaScreen() : const AnggotaScreen()),
    );
  }

  // --- UI STYLING ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tombol Kembali / Logout
                GestureDetector(
                  onTap: () async {
                    await AuthService().signOut();
                    if (!mounted) return;
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text("Kembali ke Login", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                const Text(
                  "Langkah Terakhir!",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1A237E)),
                ),
                const SizedBox(height: 10),
                Text(
                  "Pilih peran Anda untuk mulai mengelola atau membayar kas grup.",
                  style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
                ),
                
                const SizedBox(height: 40),

                // CARD BUAT GRUP
                _buildChoiceCard(
                  title: "Saya Bendahara",
                  subtitle: "Buat grup baru dan kelola keuangan transparan.",
                  icon: Icons.admin_panel_settings_rounded,
                  color: const Color(0xFF1A237E),
                  onTap: () => _showDialogInput(
                    "Buat Grup Baru",
                    "Nama Grup (Contoh: Kas Kelas X-A)",
                    _groupNameController,
                    _createGroup,
                  ),
                ),

                const SizedBox(height: 20),

                // CARD GABUNG GRUP
                _buildChoiceCard(
                  title: "Saya Anggota",
                  subtitle: "Masuk ke grup yang sudah ada menggunakan kode.",
                  icon: Icons.group_add_rounded,
                  color: Colors.teal[600]!,
                  onTap: () => _showDialogInput(
                    "Gabung ke Grup",
                    "Masukkan Kode Grup dari Bendahara",
                    _joinCodeController,
                    _joinGroup,
                  ),
                ),
              ],
            ),
          ),
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(25),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: const EdgeInsets.all(25),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2D3142))),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _showDialogInput(String title, String hint, TextEditingController controller, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A237E))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Batal", style: TextStyle(color: Colors.grey[600]))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text("Lanjutkan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E))),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }
}