import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import  'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> registerUser(
    String email,
    String password,
    String nama,
  ) async {
    try {
      UserCredential res = await _auth
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 10));

      if (res.user != null) {
        await _firestore.collection('users').doc(res.user!.uid).set({
          'uid': res.user!.uid,
          'name': nama,
          'email': email,
          'role': null,
          'groupId': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Email sudah digunakan';
        case 'weak-password':
          return 'Password terlalu lemah';
        default:
          return 'Registrasi gagal, coba lagi';
      }
    } catch (e) {
      debugPrint("Register error: $e");
      return 'Terjadi kesalahan sistem';
    }
  }

  Future<Map<String, dynamic>?> loginUser(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 10));

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
      return null;
    } on FirebaseAuthException {
      throw "Email atau Password salah.";
    } catch (e) {
      debugPrint("Login error: $e");
      throw "Terjadi kesalahan sistem";
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}