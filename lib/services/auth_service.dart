import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> registerAnggota(String email, String password, String nama) async {
    try {
      // Firebase akan otomatis mengecek email di sini
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      
      // Jika berhasil, simpan ke Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'nama': nama,
        'email': email,
        'role': 'anggota',
        'createdAt': DateTime.now(),
      });
      
      return null; // Berhasil
    } on FirebaseAuthException catch (e) {
      // INI ADALAH BAGIAN VALIDASI EMAIL UNIK
      if (e.code == 'email-already-in-use') {
        return "Email ini sudah terdaftar. Gunakan email lain atau silakan login.";
      } else if (e.code == 'weak-password') {
        return "Password terlalu lemah.";
      } else if (e.code == 'invalid-email') {
        return "Format email tidak valid.";
      }
      return e.message; // Pesan error lainnya dari Firebase
    } catch (e) {
      return "Terjadi kesalahan: $e";
    }
  }

  // Fungsi Login tetap sama seperti sebelumnya
  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw "Email atau Password salah.";
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}