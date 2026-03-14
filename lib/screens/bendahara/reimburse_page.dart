import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReimbursePage extends StatelessWidget {
  const ReimbursePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ceklis Reimburse")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reimbursements').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index];
              bool isPaid = data['status'] == 'dibayar';
              return CheckboxListTile(
                title: Text(data['nama_anggota']),
                subtitle: Text("Rp ${data['jumlah']} - ${data['keperluan']}"),
                value: isPaid,
                onChanged: (val) {
                  FirebaseFirestore.instance.collection('reimbursements').doc(data.id).update({
                    'status': val! ? 'dibayar' : 'pending'
                  });
                },
              );
            },
          );
        },
      ),
    );
  }
}