import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Di dalam AuthService
  Future<String?> registerUser(
    String email,
    String password,
    String nama,
  ) async {
    try {
      UserCredential res = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _firestore.collection('users').doc(res.user!.uid).set({
        'uid': res.user!.uid,
        'name': nama,
        'email': email,
        'role': 'none', // Default awal
        'groupId': '', // Belum punya grup
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Fungsi Login tetap sama seperti sebelumnya
  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        throw "Email atau Password salah.";
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
