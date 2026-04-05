import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '/services/error_service.dart';

class CashFlowPage extends StatefulWidget {
  const CashFlowPage({super.key});

  @override
  State<CashFlowPage> createState() => _CashFlowPageState();
}

class _CashFlowPageState extends State<CashFlowPage> {
  final Color primaryNavy = const Color(0xFF1A237E);
  final Color backgroundColor = const Color(0xFFF4F6F8);
  
  String? _userGroupId;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserGroupId();
  }

  Future<void> _loadUserGroupId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && mounted) {
          setState(() {
            _userGroupId = userDoc['groupId'];
            _isLoadingUser = false;
          });
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ErrorService.show(context, e); // Aman dipanggil di sini karena ini fungsi async, bukan di dalam build()
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  String _formatCurrency(double value) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(value);
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return "-";
    if (ts is Timestamp) {
      return DateFormat('dd MMM yyyy').format(ts.toDate());
    }
    return "-";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryNavy,
        title: const Text("Riwayat Cash Flow", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingUser 
      ? Center(child: CircularProgressIndicator(color: primaryNavy))
      : _userGroupId == null || _userGroupId!.isEmpty
        ? _buildNoGroupState() // Cegah query jika user belum punya grup
        : Stack(
            children:[
              // Background Header Biru
              Container(
                height: 60, // Ketinggian disesuaikan agar proporsional
                decoration: BoxDecoration(
                  color: primaryNavy,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
              ),
              
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('transactions')
                    .where('groupId', isEqualTo: _userGroupId)
                    .orderBy('date', descending: true)
                    .limit(100) // Batasi query demi performa
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }
                  
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      var data = doc.data() as Map<String, dynamic>;
                      bool isMasuk = data['type'] == 'masuk';

                      return _buildTransactionCard(data, isMasuk);
                    },
                  );
                },
              ),
            ],
          ),
    );
  }

  // --- FIX OVERFLOW: Menggunakan Custom Row pengganti ListTile ---
  Widget _buildTransactionCard(Map<String, dynamic> data, bool isMasuk) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow:[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children:[
          // Ikon Transaksi
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMasuk ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isMasuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isMasuk ? Colors.green[700] : Colors.red[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          
          // Keterangan & Tanggal (Gunakan Expanded agar sisa layar terisi otomatis)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                Text(
                  data['keterangan'] ?? "Tanpa Keterangan",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D3142)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis, // Cegah tulisan panjang jebol ke bawah
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(data['date']),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          
          // Nominal Uang (Dibungkus Flexible + FittedBox agar angka besar mengecil otomatis)
          Flexible(
            flex: 0,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                "${isMasuk ? '+' : '-'} ${_formatCurrency((data['jumlah'] ?? 0).toDouble())}",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: isMasuk ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
          ),
        ],
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
            "Anda belum bergabung ke grup mana pun.",
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
          Icon(Icons.receipt_long_rounded, size: 80, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 15),
          const Text(
            "Belum ada riwayat transaksi",
            style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
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
                ? "Database memerlukan sinkronisasi indeks. Silakan hubungi pengembang." 
                : error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}