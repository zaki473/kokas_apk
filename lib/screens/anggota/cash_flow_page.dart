import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CashFlowPage extends StatelessWidget {
  const CashFlowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Riwayat Cash Flow"), backgroundColor: Colors.blue[700]),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('transactions').orderBy('date', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index];
              bool isMasuk = data['type'] == 'masuk';
              return ListTile(
                leading: Icon(isMasuk ? Icons.add_circle : Icons.remove_circle, color: isMasuk ? Colors.green : Colors.red),
                title: Text(data['keterangan']),
                subtitle: Text(DateFormat('dd MMM yyyy').format(data['date'].toDate())),
                trailing: Text("Rp ${data['jumlah']}", style: TextStyle(color: isMasuk ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
              );
            },
          );
        },
      ),
    );
  }
}