import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class FCMService {
  static const String projectId = "ISI_PROJECT_ID_KAMU";

  static Future<void> sendNotificationToGroup({
    required String groupId,
    required String title,
    required String body,
  }) async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/service_account.json');

      final credentials =
          ServiceAccountCredentials.fromJson(jsonString);

      final scopes = [
        'https://www.googleapis.com/auth/firebase.messaging'
      ];

      final client =
          await clientViaServiceAccount(credentials, scopes);

      final accessToken = client.credentials.accessToken.data;

      final url =
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final payload = {
        "message": {
          "topic": "group_$groupId",
          "notification": {
            "title": title,
            "body": body,
          },
          "android": {
            "priority": "HIGH",
            "notification": {
              "channel_id": "high_importance_channel"
            }
          },
          "data": {
            "tipe": "pengumuman",
            "groupId": groupId,
          }
        }
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ FCM BERHASIL DIKIRIM");
      } else {
        debugPrint("❌ GAGAL FCM");
        debugPrint(response.body);
      }
    } catch (e) {
      debugPrint("❌ ERROR FCM: $e");
    }
  }
}