import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class ImageHelper {
  static Future<String?> pickAndCompress() async {
    final ImagePicker picker = ImagePicker();
    
    // 1. Ambil Gambar dari Galeri
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;

    // 2. Path untuk file output sementara
    final String targetPath = "${image.path}_compressed.jpg";

    // 3. Proses Kompresi (Target: di bawah 200KB)
    XFile? result = await FlutterImageCompress.compressAndGetFile(
      image.path,
      targetPath,
      quality: 35,      // Kualitas 35% sangat hemat ruang
      minWidth: 800,    // Lebar maksimal 800px
      minHeight: 800,   // Tinggi maksimal 800px
    );

    if (result == null) return null;

    // 4. Ubah ke Base64
    File compressedFile = File(result.path);
    List<int> imageBytes = await compressedFile.readAsBytes();
    String base64String = base64Encode(imageBytes);

    // Hapus file sampah di memori HP
    await compressedFile.delete();

    return base64String;
  }
}