import 'dart:io';
import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:firebase_auth/firebase_auth.dart';

class ErrorService {
  static const Color navyColor = Color(0xFF1A237E);
  static const Color errorRed = Color(0xFFE53935);
  static const Color warningAmber = Color(0xFFFFA000);
  static const Color successGreen = Color(0xFF43A047);

  /// Menampilkan dialog error/warning. 
  /// Mengembalikan Future sehingga bisa di-await jika perlu.
  static Future<void> show(BuildContext context, dynamic error) async {
    HapticFeedback.vibrate();

    String title = "Ups! Ada Masalah";
    String message = "Sesuatu yang salah terjadi. Silakan coba lagi nanti.";
    IconData icon = Icons.error_outline_rounded;
    Color color = errorRed;

    String errorString = error.toString();

    // 1. Deteksi Waktu Habis (Timeout)
    if (error is TimeoutException) {
      title = "Waktu Habis";
      message = "Koneksi internetmu terlalu lambat. Silakan cek jaringan dan coba lagi.";
      icon = Icons.timer_off_rounded;
      color = warningAmber;
    } 
    // 2. Deteksi Koneksi Terputus
    else if (error is SocketException || 
             errorString.contains('network-request-failed') || 
             errorString.contains('ERR_INTERNET_DISCONNECTED')) {
      title = "Cek Jaringan Anda";
      message = "Kamu sedang offline. Pastikan kuota dan internetmu aktif ya!";
      icon = Icons.wifi_off_rounded;
      color = warningAmber;
    } 
    // 3. Deteksi Error Firebase Auth
    else if (error is FirebaseAuthException) {
      title = "Gagal Masuk";
      message = _mapAuthError(error.code);
      icon = Icons.lock_person_rounded;
      color = errorRed;
    }
    // 4. Deteksi Error Firestore/Firebase Umum
    else if (error is FirebaseException) {
      title = "Masalah Database";
      message = _mapFirebaseError(error.code);
      icon = Icons.cloud_off_rounded;
      color = errorRed;
    } 
    // 5. Jika error berupa String manual
    else if (error is String) {
      message = error;
    }

    // Tampilkan dialog dan tunggu sampai ditutup
    await _showBeautifulDialog(context, title, message, icon, color);
  }

  /// Menampilkan dialog sukses. 
  /// WAJIB di-await di UI agar Navigator.pop tidak jalan duluan.
  static Future<void> showSuccess(BuildContext context, String message) async {
    HapticFeedback.lightImpact();
    await _showBeautifulDialog(
      context, 
      "Berhasil!", 
      message, 
      Icons.check_circle_outline_rounded, 
      successGreen,
    );
  }

  // --- PEMETAAN PESAN MANUSIAWI ---
  static String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found': return "Email ini belum terdaftar di KOKAS.";
      case 'wrong-password': return "Password yang kamu masukkan salah.";
      case 'email-already-in-use': return "Email ini sudah dipakai akun lain.";
      case 'invalid-email': return "Format email yang kamu masukkan salah.";
      case 'too-many-requests': return "Terlalu banyak percobaan. Coba lagi sebentar lagi.";
      case 'weak-password': return "Password terlalu lemah. Gunakan minimal 6 karakter.";
      default: return "Gagal memproses akun ($code).";
    }
  }

  static String _mapFirebaseError(String code) {
    switch (code) {
      case 'permission-denied': return "Izin ditolak oleh sistem. Pastikan akunmu aktif.";
      case 'unavailable': return "Server sedang sibuk. Tunggu sebentar ya.";
      default: return "Terjadi gangguan pada sistem database ($code).";
    }
  }

  // --- UI DIALOG UTAMA (CORE) ---
  static Future<void> _showBeautifulDialog(
    BuildContext context, 
    String title, 
    String message, 
    IconData icon, 
    Color mainColor,
  ) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Tutup",
      barrierColor: Colors.black54, // Gelapkan background agar fokus ke dialog
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curvedValue = Curves.easeInOutBack.transform(anim1.value);
        return Transform.scale(
          scale: curvedValue,
          child: Opacity(
            opacity: anim1.value,
            child: Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Bagian Icon Atas
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 25),
                    decoration: BoxDecoration(color: mainColor.withOpacity(0.1)),
                    child: Icon(icon, color: mainColor, size: 60),
                  ),
                  // Bagian Konten Teks
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          title, 
                          textAlign: TextAlign.center, 
                          style: TextStyle(
                            fontSize: 22, 
                            fontWeight: FontWeight.bold, 
                            color: mainColor == successGreen ? successGreen : navyColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          message, 
                          textAlign: TextAlign.center, 
                          style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.5),
                        ),
                        const SizedBox(height: 30),
                        // Tombol Konfirmasi
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: navyColor, 
                              foregroundColor: Colors.white, 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: () => Navigator.of(context).pop(), // Menutup dialog saja
                            child: const Text(
                              "OKAI, MENGERTI", 
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}